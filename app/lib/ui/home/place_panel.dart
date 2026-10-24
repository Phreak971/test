import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/geo.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/location.dart';
import '../../state/providers.dart';
import '../hud.dart';

/// Shareable link that opens anywhere (no proprietary map links).
Uri osmLink(Geo g) => Uri.parse(
  'https://www.openstreetmap.org/?mlat=${g.lat.toStringAsFixed(6)}&mlon=${g.lng.toStringAsFixed(6)}#map=17/${g.lat.toStringAsFixed(6)}/${g.lng.toStringAsFixed(6)}',
);

/// Finds a saved place at (almost) the same spot.
SavedPlace? savedMatch(List<SavedPlace> saved, Place p) {
  for (final s in saved) {
    if (s.id == p.id || distanceM(s.location, p.location) < 15) return s;
  }
  return null;
}

class PlacePanel extends ConsumerWidget {
  const PlacePanel({
    super.key,
    required this.place,
    required this.onClose,
    required this.onDirections,
    required this.onSave,
    required this.onEdit,
  });

  final Place place;
  final VoidCallback onClose;
  final VoidCallback onDirections;
  final VoidCallback onSave;
  final ValueChanged<SavedPlace> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final unit = ref.watch(settingsProvider.select((s) => s.unit));
    final me = ref.watch(locationProvider.select((s) => s.position));
    final saved = savedMatch(ref.watch(placesProvider), place);
    final title = place.isPinned && place.name.isEmpty ? l.pinnedLocation : place.name;
    final subtitle = [
      if (place.isPinned) l.pinnedLocation else ?place.category,
      if (me != null) l.distanceAway(formatDistance(distanceM(me, place.location), unit)),
    ].join(' · ');

    return HudPanel(
      hud: hud,
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 16),
      radius: hud.radius.clamp(12, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: displayStyle(hud, 22), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: hud.accentText, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                    if (place.address != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        place.address!,
                        style: TextStyle(color: hud.muted, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close_rounded, color: hud.muted),
                tooltip: l.close,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PrimaryButton(hud: hud, label: l.getDirections, icon: Icons.directions_rounded, onPressed: onDirections),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Action(
                  hud: hud,
                  icon: saved != null ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                  label: saved != null ? l.edit : l.savePlace,
                  onTap: saved != null ? () => onEdit(saved) : onSave,
                ),
                if (place.phone != null)
                  _Action(
                    hud: hud,
                    icon: Icons.call_rounded,
                    label: l.call,
                    onTap: () => launchUrl(Uri(scheme: 'tel', path: place.phone)),
                  ),
                if (place.website != null)
                  _Action(
                    hud: hud,
                    icon: Icons.public_rounded,
                    label: l.website,
                    onTap: () {
                      final w = place.website!;
                      launchUrl(Uri.parse(w.startsWith('http') ? w : 'https://$w'), mode: LaunchMode.externalApplication);
                    },
                  ),
                if (place.social != null)
                  _Action(
                    hud: hud,
                    icon: Icons.camera_alt_rounded,
                    label: 'Instagram',
                    onTap: () => launchUrl(Uri.parse(place.social!), mode: LaunchMode.externalApplication),
                  ),
                _Action(
                  hud: hud,
                  icon: shareIcon,
                  label: l.share,
                  onTap: () {
                    final box = context.findRenderObject() as RenderBox?;
                    SharePlus.instance.share(
                      ShareParams(
                        text: [title, ?place.address, osmLink(place.location).toString()].join('\n'),
                        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.hud, required this.icon, required this.label, required this.onTap});

  final Hud hud;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: hud.text.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(hud.radius.clamp(6, 22)),
          child: InkWell(
            borderRadius: BorderRadius.circular(hud.radius.clamp(6, 22)),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: hud.text, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(color: hud.text, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
