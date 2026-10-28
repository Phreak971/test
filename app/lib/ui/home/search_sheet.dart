import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo.dart';
import '../../core/geo_uri.dart';
import '../../core/map_link.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/location.dart';
import '../../state/providers.dart';
import '../hud.dart';

String categoryLabel(L l, NearbyCategory c) => switch (c) {
  NearbyCategory.restaurant => l.catRestaurant,
  NearbyCategory.fastFood => l.catFastFood,
  NearbyCategory.cafe => l.catCafe,
  NearbyCategory.fuel => l.catFuel,
  NearbyCategory.charging => l.catCharging,
  NearbyCategory.parking => l.catParking,
  NearbyCategory.hotel => l.catHotel,
  NearbyCategory.supermarket => l.catSupermarket,
  NearbyCategory.pharmacy => l.catPharmacy,
  NearbyCategory.hospital => l.catHospital,
  NearbyCategory.subway => l.catSubway,
  NearbyCategory.bank => l.catBank,
};

IconData categoryIcon(NearbyCategory c) => switch (c) {
  NearbyCategory.restaurant => Icons.restaurant,
  NearbyCategory.fastFood => Icons.fastfood,
  NearbyCategory.cafe => Icons.local_cafe,
  NearbyCategory.fuel => Icons.local_gas_station,
  NearbyCategory.charging => Icons.ev_station,
  NearbyCategory.parking => Icons.local_parking,
  NearbyCategory.hotel => Icons.hotel,
  NearbyCategory.supermarket => Icons.shopping_basket,
  NearbyCategory.pharmacy => Icons.medication,
  NearbyCategory.hospital => Icons.local_hospital,
  NearbyCategory.subway => Icons.subway,
  NearbyCategory.bank => Icons.account_balance,
};

/// Result of the sheet: a single place, or a list to show on the map.
sealed class SearchOutcome {
  const SearchOutcome();
}

/// Nearby results to plot on the map.
class ShowOnMap extends SearchOutcome {
  const ShowOnMap(this.category, this.places);

  final NearbyCategory category;
  final List<Place> places;
}

class PickedPlace extends SearchOutcome {
  const PickedPlace(this.place);

  final Place place;
}

/// Full-height search: query, recents, and nearby categories.
class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({super.key, required this.center, this.initialCategory, this.initialQuery, this.autofocus = true});

  /// Where to bias results (map centre or user).
  final Geo center;
  final NearbyCategory? initialCategory;
  final String? initialQuery;
  final bool autofocus;

  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<SearchSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  int _token = 0;
  List<Place>? _results;
  NearbyCategory? _category;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _ctrl.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runQuery(widget.initialQuery!));
    } else if (widget.initialCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runCategory(widget.initialCategory!));
    } else if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _lang => Localizations.localeOf(context).languageCode;

  void _onChanged(String q) {
    _debounce?.cancel();
    setState(() => _category = null);
    if (q.trim().length < 2) {
      _token++; // discard any request still in flight
      setState(() {
        _results = null;
        _loading = false;
        _error = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _runQuery(q));
  }

  /// A pasted map link (Overworld, OSM, Google, Apple, geo:) or typed
  /// "lat, lng" goes straight to that spot instead of a text search.
  Place? _linkedPlace(String q) {
    final link = MapLinks.parse(q) ?? GeoUri.parse('geo:0,0?q=${Uri.encodeQueryComponent(q.trim())}');
    final at = link?.point;
    if (at == null) return null;
    return Place(
      id: 'link:${at.lat.toStringAsFixed(6)},${at.lng.toStringAsFixed(6)}',
      name: link!.label ?? L.of(context).pinnedLocation,
      location: at,
      isPinned: link.label == null,
    );
  }

  Future<void> _runQuery(String q) async {
    final token = ++_token;
    final linked = _linkedPlace(q);
    if (linked != null) {
      setState(() {
        _results = [linked];
        _loading = false;
        _error = false;
      });
      return;
    }
    // A link to a search ("maps.google.com/?q=pizza") searches its text.
    final text = MapLinks.parse(q)?.query ?? q;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final r = await ref.read(searchServiceProvider).autocomplete(text, near: widget.center, lang: _lang);
      if (!mounted || token != _token) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _runCategory(NearbyCategory c) async {
    _debounce?.cancel();
    final token = ++_token;
    _focus.unfocus();
    setState(() {
      _category = c;
      _loading = true;
      _error = false;
      _results = null;
    });
    try {
      final r = await ref.read(searchServiceProvider).nearby(c, widget.center, lang: _lang);
      if (!mounted || token != _token) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _pick(Place p) {
    ref.read(historyProvider.notifier).record(p);
    Navigator.of(context).pop(PickedPlace(p));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final history = ref.watch(historyProvider);
    final unit = ref.watch(settingsProvider.select((s) => s.unit));
    final me = ref.watch(locationProvider.select((s) => s.position)) ?? widget.center;
    final showingResults = _results != null || _loading || _error;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onChanged: _onChanged,
                  onSubmitted: (q) => q.trim().length >= 2 ? _runQuery(q) : null,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: hud.text, fontSize: 17),
                  decoration: InputDecoration(
                    hintText: l.searchHint,
                    prefixIcon: Icon(Icons.search_rounded, color: hud.muted),
                    suffixIcon: _ctrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l.clearText,
                            icon: Icon(Icons.cancel_rounded, color: hud.muted),
                            onPressed: () {
                              _ctrl.clear();
                              _onChanged('');
                            },
                          ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l.cancel,
                  style: TextStyle(color: hud.accentText, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: showingResults
              ? _ResultsList(
                  hud: hud,
                  loading: _loading,
                  error: _error,
                  results: _results ?? const [],
                  title: _category == null ? null : categoryLabel(l, _category!),
                  emptyTitle: _category == null ? l.noResultsTitle : l.nearbyEmpty,
                  emptyBody: _category == null ? l.noResultsBody : null,
                  me: me,
                  unit: unit,
                  onPick: _pick,
                  onRetry: () => _category != null ? _runCategory(_category!) : _runQuery(_ctrl.text),
                  onShowOnMap: _category == null || (_results?.isEmpty ?? true) || _loading
                      ? null
                      : () => Navigator.of(context).pop(ShowOnMap(_category!, _results!)),
                  onBack: _category == null
                      ? null
                      : () => setState(() {
                          _category = null;
                          _results = null;
                        }),
                )
              : ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    HudSectionHeader(hud: hud, text: l.findNearby),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in NearbyCategory.values)
                            ActionChip(
                              avatar: Icon(categoryIcon(c), size: 18, color: hud.accentText),
                              label: Text(categoryLabel(l, c)),
                              labelStyle: TextStyle(color: hud.text, fontWeight: FontWeight.w600),
                              backgroundColor: hud.text.withValues(alpha: 0.07),
                              side: BorderSide(color: hud.text.withValues(alpha: 0.12)),
                              materialTapTargetSize: MaterialTapTargetSize.padded,
                              onPressed: () => _runCategory(c),
                            ),
                        ],
                      ),
                    ),
                    if (history.isNotEmpty) ...[
                      HudSectionHeader(
                        hud: hud,
                        text: l.recent,
                        trailing: TextButton(
                          onPressed: () => ref.read(historyProvider.notifier).clear(),
                          child: Text(
                            l.clearHistory,
                            style: TextStyle(color: hud.accentText, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      for (final h in history)
                        _PlaceTile(
                          hud: hud,
                          place: h.place,
                          me: me,
                          unit: unit,
                          leading: Icons.history_rounded,
                          onTap: () => _pick(h.place),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.hud,
    required this.loading,
    required this.error,
    required this.results,
    required this.emptyTitle,
    required this.me,
    required this.unit,
    required this.onPick,
    required this.onRetry,
    this.title,
    this.emptyBody,
    this.onBack,
    this.onShowOnMap,
  });

  final Hud hud;
  final bool loading;
  final bool error;
  final List<Place> results;
  final String? title;
  final String emptyTitle;
  final String? emptyBody;
  final Geo me;
  final DistanceUnit unit;
  final ValueChanged<Place> onPick;
  final VoidCallback onRetry;
  final VoidCallback? onBack;
  final VoidCallback? onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    Widget content;
    if (loading) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(color: hud.accentText),
        ),
      );
    } else if (error) {
      content = _Empty(
        hud: hud,
        icon: Icons.wifi_off_rounded,
        title: l.searchUnavailable,
        action: TextButton(onPressed: onRetry, child: Text(l.retry)),
      );
    } else if (results.isEmpty) {
      content = _Empty(hud: hud, icon: Icons.search_off_rounded, title: emptyTitle, body: emptyBody);
    } else {
      content = ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: results.length,
        itemBuilder: (_, i) => _PlaceTile(hud: hud, place: results[i], me: me, unit: unit, onTap: () => onPick(results[i])),
      );
    }
    return Column(
      children: [
        if (title != null)
          ListTile(
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icon(Icons.arrow_back_rounded, color: hud.text),
              onPressed: onBack,
            ),
            title: Text(title!, style: displayStyle(hud, 18)),
            trailing: onShowOnMap == null
                ? null
                : TextButton.icon(onPressed: onShowOnMap, icon: const Icon(Icons.map_rounded), label: Text(l.showOnMap)),
          ),
        Expanded(child: content),
      ],
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.hud,
    required this.place,
    required this.me,
    required this.unit,
    required this.onTap,
    this.leading = Icons.place_rounded,
  });

  final Hud hud;
  final Place place;
  final Geo me;
  final DistanceUnit unit;
  final VoidCallback onTap;
  final IconData leading;

  @override
  Widget build(BuildContext context) {
    final d = formatDistance(distanceM(me, place.location), unit);
    return ListTile(
      minTileHeight: 56,
      leading: CircleAvatar(
        backgroundColor: hud.accent.withValues(alpha: 0.18),
        child: Icon(leading, color: hud.accentText, size: 20),
      ),
      title: Text(
        place.name,
        style: TextStyle(color: hud.text, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [?place.category, ?place.address].join(' · '),
        style: TextStyle(color: hud.muted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        d,
        style: TextStyle(color: hud.muted, fontSize: 13, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hud, required this.icon, required this.title, this.body, this.action});

  final Hud hud;
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: hud.muted, size: 48),
            const SizedBox(height: 12),
            Text(title, style: displayStyle(hud, 18), textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                style: TextStyle(color: hud.muted),
                textAlign: TextAlign.center,
              ),
            ],
            ?action,
          ],
        ),
      ),
    );
  }
}
