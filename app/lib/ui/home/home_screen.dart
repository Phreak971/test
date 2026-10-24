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
import '../../themes/map_theme.dart';
import '../../themes/style_builder.dart';
import '../../themes/theme_catalog.dart';
import '../hud.dart';
import '../map/game_map.dart';
import '../map/map_overlay_fx.dart';
import '../paywall/paywall_screen.dart';
import '../settings/settings_screen.dart';
import '../themes/theme_picker_screen.dart';
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

  void _toggleAppearance() {
    final a = ref.read(activeThemeProvider);
    final nextDark = a.variant != MapVariant.dark;
    ref.read(settingsProvider.notifier).setPreferDark(nextDark == (a.theme.baseVariant == MapVariant.dark) ? null : nextDark);
  }

  Future<void> _openMore(BuildContext button, MapVariant variant) async {
    final l = L.of(context);
    final hud = ref.read(hudProvider);
    final box = button.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final choice = await showMenu<String>(
      context: context,
      color: hud.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(hud.radius.clamp(8, 18))),
      position: RelativeRect.fromRect(topLeft & box.size, Offset.zero & overlay.size),
      items: [
        for (final (id, icon, label) in [
          ('nearby', Icons.local_dining_rounded, l.railNearby),
          ('home', Icons.home_rounded, l.railHome),
          ('appearance', variant == MapVariant.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, l.mapAppearance),
        ])
          PopupMenuItem(
            value: id,
            height: 52,
            child: Row(
              children: [
                Icon(icon, color: hud.accentText),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(color: hud.text, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
    switch (choice) {
      case 'nearby':
        await _openSearch(nearby: true);
      case 'home':
        _goHome();
      case 'appearance':
        _toggleAppearance();
    }
  }

  void _openThemes() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ThemePickerScreen()));

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  void _onGeoLink(GeoUri? _, GeoUri? link) {
    if (link == null) return;
    // Never silently end active guidance; keep the link for afterwards.
    if (ref.read(navProvider) is NavActive) return;
    Future.microtask(() => ref.read(pendingGeoLinkProvider.notifier).set(null));
    if (link.point != null) {
      _select(
        Place(
          id: 'geo:${link.point!.lat},${link.point!.lng}',
          name: link.label ?? L.of(context).pinnedLocation,
          location: link.point!,
          isPinned: link.label == null,
        ),
      );
    } else if (link.query != null) {
      _openSearch(query: link.query);
    }
  }

  // -------------------------------------------------------------- build

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
    final unlocked = ref.watch(themeUnlockedProvider(theme.id));
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
    final mq = MediaQuery.of(context);
    _map.reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget? bottom;
    if (nav is NavPreview) {
      bottom = RoutePreviewPanel(key: const ValueKey('preview'), state: nav, onClose: () => ref.read(navProvider.notifier).cancel());
    } else if (nav is NavActive) {
      bottom = NavBottomBar(key: const ValueKey('navbar'), state: nav, onEnd: () => ref.read(navProvider.notifier).cancel());
    } else if (nav is NavArrived) {
      bottom = ArrivedPanel(key: const ValueKey('arrived'), dest: nav.dest, onDone: () => ref.read(navProvider.notifier).cancel());
    } else if (_selected != null) {
      bottom = PlacePanel(
        key: ValueKey('place-${_selected!.id}'),
        place: _selected!,
        onClose: () => setState(() => _selected = null),
        onDirections: () => _directions(_selected!),
        onSave: () => _savePlace(_selected!),
        onEdit: _editSaved,
      );
    }

    return PopScope(
      canPop: _selected == null && nav is NavIdle,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (nav is! NavIdle) {
          ref.read(navProvider.notifier).cancel();
        } else {
          setState(() => _selected = null);
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
                    pin: _selected?.isPinned == true ? _selected!.location : null,
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

              // Title badge (top-left) or maneuver banner while navigating.
              Positioned(
                left: 12 + mq.padding.left,
                right: (navigating ? 12 : 76) + mq.padding.right,
                top: mq.padding.top + 8,
                child: navigating
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: ManeuverBanner(state: nav),
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: _TitleBadge(hud: hud, theme: theme, variant: variant, onTap: _openThemes),
                      ),
              ),

              if (_results != null && !navigating)
                Positioned(
                  left: 12 + mq.padding.left,
                  top: mq.padding.top + 80,
                  child: InputChip(
                    avatar: Icon(categoryIcon(_results!.$1), size: 18, color: hud.accentText),
                    label: Text('${categoryLabel(l, _results!.$1)} · ${_results!.$2.length}'),
                    labelStyle: TextStyle(color: hud.text, fontWeight: FontWeight.w700),
                    backgroundColor: hud.panel,
                    side: BorderSide(color: hud.text.withValues(alpha: 0.15)),
                    deleteIcon: Icon(Icons.close_rounded, color: hud.muted, size: 18),
                    deleteButtonTooltipMessage: l.close,
                    onDeleted: () => setState(() => _results = null),
                    onPressed: () => _openSearch(category: _results!.$1),
                  ),
                ),

              // Right rail: four primary actions plus a "More" menu so it fits
              // above the map controls on small phones and in landscape.
              if (!navigating && (bottom == null || mq.size.height >= 700))
                Positioned(
                  right: 12 + mq.padding.right,
                  top: mq.padding.top + 8,
                  bottom: mq.padding.bottom + (bottom != null ? 16 + _bottomInset(nav) + 64 : _attributionClearance + 128),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final b in <Widget>[
                          HudIconButton(hud: hud, icon: Icons.search_rounded, label: l.railSearch, onPressed: _openSearch),
                          HudIconButton(hud: hud, icon: Icons.map_rounded, label: l.railChangeMap, onPressed: _openThemes),
                          HudIconButton(hud: hud, icon: Icons.bookmarks_rounded, label: l.railSaved, onPressed: _openSaved),
                          Builder(
                            builder: (btn) => HudIconButton(
                              hud: hud,
                              icon: Icons.more_horiz_rounded,
                              label: l.railMore,
                              onPressed: () => _openMore(btn, variant),
                            ),
                          ),
                          HudIconButton(hud: hud, icon: Icons.settings_rounded, label: l.railSettings, onPressed: _openSettings),
                        ])
                          Padding(padding: const EdgeInsets.only(bottom: 8), child: b),
                      ],
                    ),
                  ),
                ),

              // Bottom-left area label + bottom-right map controls.
              if (bottom == null)
                Positioned(
                  left: 12 + mq.padding.left,
                  bottom: mq.padding.bottom + _attributionClearance,
                  right: 140,
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
              Positioned(
                right: 12 + mq.padding.right,
                bottom: mq.padding.bottom + (bottom != null ? 16 + _bottomInset(nav) : _attributionClearance),
                child: Column(
                  children: [
                    if (_bearing.abs() > 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: HudIconButton(
                          hud: hud,
                          icon: Icons.explore_rounded,
                          label: l.railCompass,
                          onPressed: () {
                            _map.resetNorth();
                            setState(() => _bearing = 0);
                          },
                        ),
                      ),
                    if (!navigating || !_follow)
                      HudIconButton(
                        hud: hud,
                        icon: _follow ? Icons.my_location_rounded : Icons.location_searching_rounded,
                        label: l.railRecenter,
                        active: _follow && loc.position != null,
                        onPressed: _recenter,
                      ),
                  ],
                ),
              ),

              // Bottom panel.
              Positioned(
                left: 8 + mq.padding.left,
                right: 8 + mq.padding.right,
                bottom: mq.padding.bottom + 8,
                // Docked bottom-left and width-capped on tablets / landscape.
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
                      transitionBuilder: (c, a) => SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                        child: FadeTransition(opacity: a, child: c),
                      ),
                      child: bottom ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

              // Modal: hide everything behind it from assistive tech.
              if (!unlocked)
                Positioned.fill(
                  child: BlockSemantics(child: _LockedOverlay(theme: theme)),
                ),
              const ToastHost(),
            ],
          ),
        ),
      ),
    );
  }

  double _bottomInset(NavState nav) => switch (nav) {
    NavActive() => 84,
    NavPreview() => 190,
    NavArrived() => 220,
    NavIdle() => 230,
  };
}

class _TitleBadge extends StatelessWidget {
  const _TitleBadge({required this.hud, required this.theme, required this.variant, required this.onTap});

  final Hud hud;
  final MapTheme theme;
  final MapVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final palette = theme.palette(variant);
    return Semantics(
      button: true,
      label: '${theme.name}, ${variant == MapVariant.dark ? l.variantDark : l.variantLight}. ${l.railChangeMap}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              theme.name.toUpperCase(),
              style: displayStyle(hud, 26, color: Color(palette.label)).copyWith(
                letterSpacing: 0.5,
                shadows: [
                  Shadow(color: Color(palette.labelHalo), blurRadius: 0, offset: const Offset(2, 2)),
                  Shadow(color: Color(palette.labelHalo), blurRadius: 8),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: hud.accent, borderRadius: BorderRadius.circular(3)),
              child: Text(
                '[${variant == MapVariant.dark ? l.variantDark : l.variantLight}]',
                style: displayStyle(hud, 12, color: hud.onAccent).copyWith(letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedOverlay extends ConsumerWidget {
  const _LockedOverlay({required this.theme});

  final MapTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: HudPanel(
              hud: hud,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, color: hud.accentText, size: 48),
                  const SizedBox(height: 10),
                  Semantics(
                    header: true,
                    child: Text(l.lockedTitle, style: displayStyle(hud, 24), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.lockedBody(theme.name),
                    style: TextStyle(color: hud.muted, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    hud: hud,
                    label: l.lockedCta,
                    icon: Icons.lock_open_rounded,
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen())),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    hud: hud,
                    label: l.lockedUseFree,
                    onPressed: () => ref.read(settingsProvider.notifier).selectTheme(themeCatalog.firstWhere((t) => !t.isPremium).id),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
