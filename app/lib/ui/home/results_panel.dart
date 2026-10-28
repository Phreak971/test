import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../hud.dart';
import 'map_chrome.dart';
import 'search_sheet.dart';

/// Nearby results for a category chip: the first few rows peek above the
/// map, drag up for the full list.
class ResultsPanel extends ConsumerWidget {
  const ResultsPanel({
    super.key,
    required this.category,
    required this.results,
    required this.from,
    required this.onPick,
    required this.onClose,
  });

  final NearbyCategory category;

  /// Null while loading.
  final List<Place>? results;

  /// Distances are measured from here (the user, or the map centre).
  final Geo from;
  final ValueChanged<Place> onPick;
  final VoidCallback onClose;

  static const _peek = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final unit = ref.watch(settingsProvider.select((s) => s.unit));
    final list = results;

    Widget tile(Place p) => ListTile(
      minTileHeight: 60,
      leading: CircleAvatar(
        backgroundColor: hud.accent.withValues(alpha: 0.18),
        child: Icon(categoryIcon(category), color: hud.accentText, size: 20),
      ),
      title: Text(
        p.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: hud.text, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [formatDistance(distanceM(from, p.location), unit), ?p.address].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: hud.muted, fontSize: 13),
      ),
      onTap: () => onPick(p),
    );

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 8, 4),
          child: Row(
            children: [
              Icon(categoryIcon(category), color: hud.accentText),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    list == null ? categoryLabel(l, category) : '${categoryLabel(l, category)} · ${l.resultsCount(list.length)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: displayStyle(hud, 18),
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: l.close,
                icon: Icon(Icons.close_rounded, color: hud.muted),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
        ),
        if (list == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
            child: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: hud.accentText)),
                const SizedBox(width: 12),
                Expanded(child: Text(l.searchingNearby, style: TextStyle(color: hud.muted))),
              ],
            ),
          )
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Text(l.nothingNearby, style: TextStyle(color: hud.muted)),
          )
        else ...[
          for (final p in list.take(_peek)) tile(p),
          const SizedBox(height: 6),
        ],
      ],
    );

    final more = list == null || list.length <= _peek
        ? null
        : Column(children: [for (final p in list.skip(_peek)) tile(p), const SizedBox(height: 8)]);
    return MapSheet(hud: hud, header: header, details: more, onDismiss: onClose);
  }
}
