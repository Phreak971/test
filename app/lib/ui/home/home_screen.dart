import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app.dart';
import '../../car/car_bridge.dart';
import '../../core/geo_uri.dart';
import '../../core/geo.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/location.dart';
import '../../state/nav_controller.dart';
import '../../state/providers.dart';
import '../../themes/style_builder.dart';
import '../hud.dart';
import '../map/game_map.dart';
import '../map/map_overlay_fx.dart';
import '../settings/settings_screen.dart';
import '../themes/theme_picker_screen.dart';
import 'map_chrome.dart';
import 'results_panel.dart';
import 'location_permission_sheet.dart';
import 'place_panel.dart';
import 'places_sheets.dart';
import 'route_panels.dart';
import 'search_sheet.dart';

const _fallbackCenter = Geo(40.7580, -73.9855);

/// Keeps map chrome clear of the (required) OSM attribution control.
const _attributionClearance = 56.0;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _map = GameMapController();
  Place? _selected;

  /// Nearby results currently plotted on the map.
  (NearbyCategory, List<Place>)? _results;

  /// Category chip whose results are loading.
  NearbyCategory? _nearbyLoading;
  int _nearbyToken = 0;

  /// Measured chrome, for control placement and the map's content insets.
  double _topH = 0;
  double _bottomH = 0;
  bool _follow = true;
  bool _centeredOnce = false;
  String? _areaName;
  Geo? _areaLookedUpAt;
  double _bearing = 0;
  late final Geo _initialCenter;
  late final double _initialZoom;

  @override
  void initState() {
    super.initState();
    final cam = ref.read(localStoreProvider).loadLastCamera();
    _initialCenter = cam == null ? _fallbackCenter : Geo(cam.lat, cam.lng);
    _initialZoom = cam?.zoom ?? 13;
    // fireImmediately: a cold-start link arrives during the splash, before
    // this screen exists.
    ref.listenManual<GeoUri?>(
      pendingGeoLinkProvider,
      (prev, next) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onGeoLink(prev, next);
      }),
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await ref.read(locationProvider.notifier).init();
      if (p == LocPermission.unknown || p == LocPermission.denied) {
        // Permission wasn't settled during onboarding (e.g. skipped).
        final st = ref.read(settingsProvider);
        if (mounted && st.onboarded && !st.locationPromptDismissed) {
          await showHudSheet<void>(context, hud: ref.read(hudProvider), builder: (_) => const LocationPermissionSheet());
        }
      }
    });
  }

  // -------------------------------------------------------------- reactions

  void _onLocation(LocationState? prev, LocationState next) {
    final fix = next.fix;
    if (fix == null) return;
    final nav = ref.read(navProvider);
    if (nav is NavActive) return; // handled by progress listener
    if (!_centeredOnce || _follow) {
      _centeredOnce = true;
      unawaited(_map.flyTo(fix.position, zoom: _follow && prev?.fix != null ? null : 15));
    }
  }

  void _onNav(NavState? prev, NavState next) {
    if (next is NavActive && prev is NavActive) {
      final a = prev.progress?.currentStepIndex, b = next.progress?.currentStepIndex;
      if (a != null && b != null && b > a) HapticFeedback.lightImpact();
    }
    if (next is NavArrived && prev is! NavArrived) {
      HapticFeedback.heavyImpact();
      final trips = ref.read(settingsProvider.notifier).recordArrival();
      // Ask for a rating only after real use (2nd and 6th trip), per HIG.
      if (trips == 2 || trips == 6) {
        unawaited(
          Future<void>.delayed(const Duration(seconds: 2), () async {
            try {
              final r = InAppReview.instance;
              if (await r.isAvailable()) await r.requestReview();
            } catch (_) {}
          }),
        );
      }
    }
    if (next is NavPreview && next.route != null && (prev is! NavPreview || prev.route != next.route)) {
      unawaited(_map.fitPoints(next.route!.geometry));
    }
    if (next is NavActive && next.progress != null) {
      final p = next.progress!;
      if (_follow) {
        unawaited(_map.flyTo(p.snapped, zoom: 17, bearing: p.bearingDeg, tilt: 50, duration: const Duration(milliseconds: 950)));
      }
    }
    if (next is NavActive && prev is! NavActive) {
      setState(() {
        _follow = true;
        _selected = null;
      });
      unawaited(WakelockPlus.enable().catchError((_) {}));
    }
    if (next is! NavActive && prev is NavActive) {
      unawaited(WakelockPlus.disable().catchError((_) {}));
      unawaited(_map.flyTo(ref.read(locationProvider).position ?? _initialCenter, tilt: 0, bearing: 0, zoom: 15));
    }
  }

  Future<void> _onCameraIdle() async {
    final cam = _map.camera;
    if (cam == null) return;
    setState(() => _bearing = cam.bearing);
    final center = toGeo(cam.target);
    unawaited(ref.read(localStoreProvider).saveLastCamera(center.lat, center.lng, cam.zoom));
    if (_areaLookedUpAt != null && distanceM(_areaLookedUpAt!, center) < 200) {
      return;
    }
    _areaLookedUpAt = center;
    try {
      final place = await ref.read(searchServiceProvider).reverse(center, lang: Localizations.localeOf(context).languageCode);
      if (!mounted) return;
      final name = place?.address?.split(',').where((s) => s.trim().isNotEmpty).firstOrNull ?? place?.name;
      setState(() => _areaName = name);
    } catch (_) {
      // Area label is decorative; ignore failures.
    }
  }

  // -------------------------------------------------------------- actions

  Geo get _searchCenter => ref.read(locationProvider).position ?? toGeo(_map.camera?.target ?? toLatLng(_initialCenter));

  Future<void> _openSearch({NearbyCategory? category, String? query, bool nearby = false}) async {
    final hud = ref.read(hudProvider);
    final res = await showHudSheet<SearchOutcome>(
      context,
      hud: hud,
      expand: true,
      // "Find nearby" opens with the category chips visible (no keyboard).
      builder: (_) => SearchSheet(center: _searchCenter, initialCategory: category, initialQuery: query, autofocus: !nearby),
    );
    if (res is PickedPlace) _select(res.place);
    if (res is ShowOnMap) {
      setState(() {
        _results = (res.category, res.places);
        _selected = null;
        _follow = false;
      });
      final me = ref.read(locationProvider).position;
      unawaited(_map.fitPoints([...res.places.map((p) => p.location), ?me]));
    }
  }

  void _select(Place p, {bool fly = true}) {
    ref.read(navProvider.notifier).cancel();
    setState(() {
      _selected = p;
      _follow = false;
    });
    if (fly) unawaited(_map.flyTo(p.location, zoom: 16));
  }

  Future<void> _onLongPress(Geo at) async {
    HapticFeedback.mediumImpact();
    final l = L.of(context);
    final pinned = Place(id: 'pin:${at.lat},${at.lng}', name: l.pinnedLocation, location: at, isPinned: true);
    _select(pinned, fly: false);
    try {
      final r = await ref.read(searchServiceProvider).reverse(at, lang: Localizations.localeOf(context).languageCode);
      if (!mounted || _selected?.id != pinned.id) return;
      setState(() => _selected = pinned.copyWith(address: r?.address == null ? r?.name : '${r!.name}, ${r.address}'));
    } catch (_) {}
  }

  void _onFeatureTap(String layer, Map<String, dynamic> props, Geo at) {
    if (layer == AppLayers.results) {
      final i = (props['rid'] as num?)?.toInt();
      final list = _results?.$2;
      if (i != null && list != null && i >= 0 && i < list.length) _select(list[i], fly: false);
      return;
    }
    if (layer == AppLayers.places) {
      final saved = ref.read(placesProvider).where((p) => p.id == props['id']).firstOrNull;
      if (saved != null) _select(saved.toPlace());
      return;
    }
    final name = (props['name:latin'] ?? props['name']) as String?;
    final cls = props['class'] as String?;
    final place = Place(
      id: 'poi:${at.lat.toStringAsFixed(6)},${at.lng.toStringAsFixed(6)}',
      name: name ?? L.of(context).unknownLocation,
      location: at,
      category: cls?.replaceAll('_', ' ').replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase()),
    );
    _select(place);
    unawaited(() async {
      try {
        final r = await ref.read(searchServiceProvider).reverse(at, lang: Localizations.localeOf(context).languageCode);
        if (!mounted || _selected?.id != place.id || r == null) return;
        setState(() => _selected = place.copyWith(address: r.address ?? r.name));
      } catch (_) {}
    }());
  }

  Future<void> _directions(Place p) async {
    final loc = ref.read(locationProvider);
    if (loc.permission != LocPermission.granted) {
      await showHudSheet<void>(context, hud: ref.read(hudProvider), builder: (_) => const LocationPermissionSheet());
      if (!mounted || ref.read(locationProvider).permission != LocPermission.granted) {
        return;
      }
    }
    setState(() => _selected = null);
    unawaited(ref.read(carBridgeProvider).previewRoute(p));
    await ref.read(navProvider.notifier).preview(p);
  }

  Future<void> _editSaved(SavedPlace s) async {
    await showHudSheet<bool>(
      context,
      hud: ref.read(hudProvider),
      builder: (_) => PlaceEditorSheet(existing: s),
    );
    if (!mounted) return;
    final still = ref.read(placesProvider).where((p) => p.id == s.id).firstOrNull;
    if (_selected != null && savedMatch([s], _selected!) != null) {
      // Keep phone/website/category from the original place; only the saved name changes.
      setState(() => _selected = still == null ? null : _selected!.copyWith(name: still.name));
    }
  }

  Future<void> _savePlace(Place p) async {
    await showHudSheet<bool>(
      context,
      hud: ref.read(hudProvider),
      builder: (_) => PlaceEditorSheet(newPlace: p),
    );
  }

  Future<void> _openSaved() async {
    final hud = ref.read(hudProvider);
    final picked = await showHudSheet<SavedPlace>(
      context,
      hud: hud,
      builder: (ctx) => SavedPlacesSheet(
        onEdit: (s) {
          Navigator.of(ctx).pop();
          _editSaved(s);
        },
      ),
    );
    if (picked != null) _select(picked.toPlace());
  }

  void _goHome() {
    final home = ref.read(homePlaceProvider);
    if (home == null) {
      ref.read(toastProvider.notifier).show(L.of(context).setHomeFirst, kind: ToastKind.info);
      _openSaved();
      return;
    }
    _directions(home.toPlace());
  }

  Future<void> _recenter() async {
    final loc = ref.read(locationProvider);
    if (loc.permission != LocPermission.granted) {
      await showHudSheet<void>(context, hud: ref.read(hudProvider), builder: (_) => const LocationPermissionSheet());
      return;
    }
    final pos = loc.position;
    if (pos == null) {
      ref.read(toastProvider.notifier).show(L.of(context).currentLocationNotFound, kind: ToastKind.error);
      return;
    }
    setState(() => _follow = true);
    await _map.flyTo(pos, zoom: 16);
  }

  Future<void> _runNearby(NearbyCategory c) async {
    final token = ++_nearbyToken;
    final cam = _map.camera;
    final center = cam == null ? _searchCenter : toGeo(cam.target);
    setState(() {
      _nearbyLoading = c;
      _results = null;
      _selected = null;
      _follow = false;
    });
    try {
      final r = await ref.read(searchServiceProvider).nearby(c, center, lang: Localizations.localeOf(context).languageCode);
      if (!mounted || token != _nearbyToken) return;
      setState(() {
        _nearbyLoading = null;
        _results = (c, r);
      });
      if (r.isNotEmpty) unawaited(_map.fitPoints([for (final p in r) p.location]));
    } catch (_) {
      if (!mounted || token != _nearbyToken) return;
      setState(() => _nearbyLoading = null);
      ref.read(toastProvider.notifier).show(L.of(context).searchUnavailable, kind: ToastKind.error);
    }
  }

  void _clearResults() => setState(() {
    _nearbyToken++;
    _nearbyLoading = null;
    _results = null;
  });

  /// Directions button: pick a destination, then preview the route.
  Future<void> _chooseDestination() async {
    final res = await showHudSheet<SearchOutcome>(
      context,
      hud: ref.read(hudProvider),
      expand: true,
      builder: (_) => SearchSheet(center: _searchCenter, autofocus: true),
    );
    if (res is PickedPlace) await _directions(res.place);
  }

  /// "Start" on a place: route and go.
  Future<void> _startTo(Place p) async {
    await _directions(p);
    final nav = ref.read(navProvider);
    if (mounted && nav is NavPreview && nav.route != null) {
      HapticFeedback.mediumImpact();
      ref.read(navProvider.notifier).start();
    }
  }

  void _setTop(Size s) {
    if ((s.height - _topH).abs() < 1) return;
    setState(() => _topH = s.height);
  }

  void _setBottom(Size s) {
    if ((s.height - _bottomH).abs() < 1) return;
    setState(() => _bottomH = s.height);
  }

  void _openThemes() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ThemePickerScreen()));

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  int _linkToken = 0;

  /// Opens an incoming link: shows the place, or previews the route when the
  /// link asked for directions. Short links and name-only links are resolved
  /// first (network), with a toast while that happens.
  Future<void> _onGeoLink(GeoUri? _, GeoUri? link) async {
    if (link == null) return;
    // Never silently end active guidance; keep the link for afterwards.
    if (ref.read(navProvider) is NavActive) return;
    Future.microtask(() => ref.read(pendingGeoLinkProvider.notifier).set(null));
    final l = L.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final token = ++_linkToken;
    final slow = link.point == null;
    if (slow) ref.read(toastProvider.notifier).show(l.openingLink, kind: ToastKind.info);
    final res = await ref.read(linkResolverProvider).resolve(link, near: _searchCenter, lang: lang, pinnedName: l.pinnedLocation);
    if (!mounted || token != _linkToken) return;
    if (res == null) {
      ref.read(toastProvider.notifier).show(l.linkUnresolved, kind: ToastKind.error);
      final q = link.query ?? link.label;
      if (q != null) unawaited(_openSearch(query: q));
      return;
    }
    if (slow) ref.read(toastProvider.notifier).dismiss();
    var place = res.place;
    if (res.navigate) {
      await _directions(place);
      return;
    }
    _select(place);
    if (place.isPinned) {
      // Name a bare coordinate like a dropped pin.
      try {
        final r = await ref.read(searchServiceProvider).reverse(place.location, lang: lang);
        if (!mounted || _selected?.id != place.id || r == null) return;
        place = place.copyWith(address: r.address == null ? r.name : '${r.name}, ${r.address}');
        setState(() => _selected = place);
      } catch (_) {}
    }
  }

  // -------------------------------------------------------------- build

  static const _chipCategories = [
    NearbyCategory.restaurant,
    NearbyCategory.cafe,
    NearbyCategory.fuel,
    NearbyCategory.supermarket,
    NearbyCategory.hotel,
    NearbyCategory.parking,
    NearbyCategory.charging,
    NearbyCategory.pharmacy,
    NearbyCategory.fastFood,
    NearbyCategory.subway,
    NearbyCategory.hospital,
    NearbyCategory.bank,
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen(locationProvider, _onLocation);
    ref.listen(navProvider, _onNav);
    ref.watch(carSyncProvider);

    final l = L.of(context);
    final active = ref.watch(activeThemeProvider);
    final theme = active.theme;
    final variant = active.variant;
    final palette = theme.palette(variant);
    final hud = ref.watch(hudProvider);
    final loc = ref.watch(locationProvider);
    final nav = ref.watch(navProvider);
    final places = ref.watch(placesProvider);

    final progress = nav is NavActive ? nav.progress : null;
    final userPos = progress?.snapped ?? loc.position;
    final userBearing = progress?.bearingDeg ?? loc.fix?.headingDeg ?? 0;
    final route = switch (nav) {
      NavPreview(:final route) => route?.geometry,
      NavActive(:final route) => route.geometry,
      _ => null,
    };
    final dest = switch (nav) {
      NavPreview(:final dest) || NavActive(:final dest) || NavArrived(:final dest) => dest.location,
      _ => null,
    };
    final navigating = nav is NavActive;
    final idle = nav is NavIdle;
    final mq = MediaQuery.of(context);
    _map.reduceMotion = MediaQuery.disableAnimationsOf(context);
    final wide = mq.size.width >= 700;
    final side = EdgeInsets.only(left: 12 + mq.padding.left, right: 12 + mq.padding.right);

    Widget? bottom;
    if (nav is NavPreview) {
      bottom = RoutePreviewPanel(
        key: ValueKey('preview-${nav.dest.id}'),
        state: nav,
        onClose: () => ref.read(navProvider.notifier).cancel(),
      );
    } else if (nav is NavActive) {
      bottom = NavBottomBar(key: const ValueKey('navbar'), state: nav, onEnd: () => ref.read(navProvider.notifier).cancel());
    } else if (nav is NavArrived) {
      bottom = ArrivedPanel(key: const ValueKey('arrived'), dest: nav.dest, onDone: () => ref.read(navProvider.notifier).cancel());
    } else if (_selected != null) {
      final p = _selected!;
      bottom = PlacePanel(
        key: ValueKey('place-${p.id}'),
        place: p,
        onClose: () => setState(() => _selected = null),
        onDirections: () => _directions(p),
        onStart: () => _startTo(p),
        onSave: () => _savePlace(p),
        onEdit: _editSaved,
      );
    } else if (_nearbyLoading != null || _results != null) {
      final cat = _nearbyLoading ?? _results!.$1;
      final cam = _map.camera;
      bottom = ResultsPanel(
        key: ValueKey('results-${cat.name}'),
        category: cat,
        results: _nearbyLoading != null ? null : _results!.$2,
        from: loc.position ?? (cam == null ? _initialCenter : toGeo(cam.target)),
        onPick: (p) => _select(p),
        onClose: _clearResults,
      );
    }

    // Keep the camera's focus clear of the chrome (Maps-style padding).
    final bottomInset = bottom == null ? 0.0 : _bottomH + 8;
    // Navigating: puck in the lower part of the screen to show the road ahead.
    final topInset = navigating ? mq.size.height * 0.45 : mq.padding.top + _topH + 8;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _map.setInsets(
          EdgeInsets.only(top: topInset, bottom: wide ? 0 : bottomInset, left: wide && bottom != null ? 480 + mq.padding.left : 0),
        ),
      );
    });

    final Widget top;
    if (navigating) {
      top = Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ManeuverBanner(state: nav),
        ),
      );
    } else if (nav is NavPreview) {
      top = Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: RouteHeaderCard(
            dest: nav.dest,
            onBack: () {
              final d = nav.dest;
              ref.read(navProvider.notifier).cancel();
              _select(d, fly: false);
            },
          ),
        ),
      );
    } else {
      final home = ref.watch(homePlaceProvider);
      final selectedCat = _nearbyLoading ?? _results?.$1;
      top = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SearchPill(hud: hud, onSearch: _openSearch, onSettings: _openSettings),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                for (final chip in <Widget>[
                  QuickChip(
                    hud: hud,
                    icon: Icons.home_rounded,
                    label: l.homeChip,
                    onTap: home == null ? _goHome : () => _directions(home.toPlace()),
                  ),
                  QuickChip(hud: hud, icon: Icons.bookmark_rounded, label: l.savedChip, onTap: _openSaved),
                  for (final c in _chipCategories)
                    QuickChip(
                      hud: hud,
                      icon: categoryIcon(c),
                      label: categoryLabel(l, c),
                      selected: c == selectedCat,
                      onTap: () => c == selectedCat ? _clearResults() : _runNearby(c),
                    ),
                ])
                  Padding(padding: const EdgeInsets.only(right: 8, bottom: 4), child: chip),
              ],
            ),
          ),
        ],
      );
    }

    final controlsBottom = mq.padding.bottom + (bottom != null && !wide ? _bottomH + 16 : _attributionClearance);

    return PopScope(
      canPop: _selected == null && _results == null && _nearbyLoading == null && idle,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!idle) {
          ref.read(navProvider.notifier).cancel();
        } else if (_selected != null) {
          setState(() => _selected = null);
        } else {
          _clearResults();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: Color(palette.land),
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(
                child: GameMap(
                  controller: _map,
                  theme: theme,
                  variant: variant,
                  initialCenter: _initialCenter,
                  initialZoom: _initialZoom,
                  overlay: MapOverlayData(
                    user: userPos,
                    userBearing: userBearing,
                    places: places,
                    // Mark whatever is selected (saved places have their own pins).
                    pin: _selected != null && savedMatch(places, _selected!) == null ? _selected!.location : null,
                    dest: dest,
                    route: route,
                    results: navigating || _results == null ? const [] : [for (final p in _results!.$2) (p, nearbyPoiIcon(_results!.$1))],
                  ),
                  onTap: (_) => setState(() => _selected = null),
                  onFeatureTap: navigating ? null : _onFeatureTap,
                  onLongPress: navigating ? null : _onLongPress,
                  onCameraIdle: _onCameraIdle,
                  onUserGesture: () {
                    if (_follow && mounted) setState(() => _follow = false);
                  },
                ),
              ),
              Positioned.fill(
                child: MapOverlayFx(overlay: theme.overlay, palette: palette),
              ),

              // Top: search + quick chips, route card, or maneuver banner.
              Positioned(
                left: side.left,
                right: side.right,
                top: mq.padding.top + 8,
                child: MeasureSize(onChange: _setTop, child: top),
              ),

              // Right column under the top chrome: map worlds, compass.
              if (!navigating)
                Positioned(
                  right: side.right,
                  top: mq.padding.top + _topH + 20,
                  child: Column(
                    children: [
                      MapFab(hud: hud, icon: Icons.layers_rounded, label: l.railChangeMap, size: 44, onPressed: _openThemes),
                      if (_bearing.abs() > 2) ...[
                        const SizedBox(height: 10),
                        MapFab(
                          hud: hud,
                          icon: Icons.explore_rounded,
                          label: l.railCompass,
                          size: 44,
                          onPressed: () {
                            _map.resetNorth();
                            setState(() => _bearing = 0);
                          },
                        ),
                      ],
                    ],
                  ),
                ),

              // Area name (bottom-left) when nothing else is there.
              if (bottom == null && idle)
                Positioned(
                  left: side.left,
                  bottom: mq.padding.bottom + _attributionClearance,
                  right: 150,
                  child: _areaName == null
                      ? const SizedBox.shrink()
                      : Semantics(
                          label: _areaName,
                          child: Text(
                            theme.uppercaseLabels ? upper(context, _areaName!) : _areaName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: displayStyle(hud, 20, color: Color(palette.label)).copyWith(
                              shadows: [
                                Shadow(color: Color(palette.labelHalo), blurRadius: 6),
                                Shadow(color: Color(palette.labelHalo), blurRadius: 2),
                              ],
                            ),
                          ),
                        ),
                ),

              // Bottom-right: directions and my location, riding above sheets
              // (hidden while a sheet is pulled up over most of the map).
              if (!navigating && (bottom == null || wide || _bottomH < mq.size.height * 0.45))
                AnimatedPositioned(
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
                  right: side.right,
                  bottom: controlsBottom,
                  child: Column(
                    children: [
                      if (bottom == null) ...[
                        MapFab(hud: hud, icon: Icons.directions_rounded, label: l.directions, primary: true, onPressed: _chooseDestination),
                        const SizedBox(height: 12),
                      ],
                      MapFab(
                        hud: hud,
                        icon: _follow ? Icons.my_location_rounded : Icons.location_searching_rounded,
                        label: l.railRecenter,
                        active: _follow && loc.position != null,
                        onPressed: _recenter,
                      ),
                    ],
                  ),
                ),

              // While navigating and panned away: Re-center.
              if (navigating && !_follow)
                Positioned(
                  left: side.left,
                  bottom: mq.padding.bottom + _bottomH + 20,
                  child: RecenterPill(hud: hud, onPressed: _recenter),
                ),

              // Bottom sheet / bar.
              Positioned(
                left: (wide ? 12 : 0) + mq.padding.left,
                right: wide ? null : mq.padding.right,
                bottom: wide ? mq.padding.bottom + 12 : 0,
                width: wide ? 480 : null,
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) => SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                    child: FadeTransition(opacity: a, child: c),
                  ),
                  child: bottom == null
                      ? const SizedBox.shrink()
                      : MeasureSize(
                          key: bottom.key,
                          onChange: _setBottom,
                          // Phone sheets run to the screen edge (they pad for
                          // the home indicator themselves); bars and tablet
                          // sheets float.
                          child: _isSheet(nav) && !wide
                              ? bottom
                              : Padding(
                                  padding: wide ? EdgeInsets.zero : EdgeInsets.fromLTRB(8, 0, 8, mq.padding.bottom + 8),
                                  child: MediaQuery.removePadding(context: context, removeBottom: true, child: bottom),
                                ),
                        ),
                ),
              ),
              const ToastHost(),
            ],
          ),
        ),
      ),
    );
  }

  /// Draggable sheets sit flush with the screen bottom; bars float.
  bool _isSheet(NavState nav) => nav is NavPreview || (nav is NavIdle);
}

/// POI icon id used to plot results of a nearby category.
String nearbyPoiIcon(NearbyCategory c) => switch (c) {
  NearbyCategory.restaurant => 'food',
  NearbyCategory.fastFood => 'fastfood',
  NearbyCategory.cafe => 'coffee',
  NearbyCategory.fuel => 'fuel',
  NearbyCategory.charging => 'charging',
  NearbyCategory.parking => 'parking',
  NearbyCategory.hotel => 'hotel',
  NearbyCategory.supermarket => 'grocery',
  NearbyCategory.pharmacy => 'pharmacy',
  NearbyCategory.hospital => 'hospital',
  NearbyCategory.subway => 'rail',
  NearbyCategory.bank => 'bank',
};
