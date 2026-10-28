import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../core/geo.dart';
import '../../core/map_link.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/location.dart';
import '../../state/providers.dart';
import '../hud.dart';
import 'map_chrome.dart';

/// Shareable link: opens Overworld when installed, a map page otherwise.
Uri placeShareLink(Place p) => MapLinks(AppConfig.shareBaseUrl).shareLink(p.location, name: p.isPinned ? null : p.name);

/// Finds a saved place at (almost) the same spot.
SavedPlace? savedMatch(List<SavedPlace> saved, Place p) {
  for (final s in saved) {
    if (s.id == p.id || distanceM(s.location, p.location) < 15) return s;
  }
  return null;
}

/// Place card, Maps-style: name, category and distance with an action row;
/// drag up for address, coordinates and contact details.
class PlacePanel extends ConsumerWidget {
  const PlacePanel({
    super.key,
    required this.place,
    required this.onClose,
    required this.onDirections,
    required this.onSave,
    required this.onEdit,
    this.onStart,
  });

  final Place place;
  final VoidCallback onClose;
  final VoidCallback onDirections;

  /// Route and start guidance straight away (null hides the button).
  final VoidCallback? onStart;
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
    final coords = '${place.location.lat.toStringAsFixed(5)}, ${place.location.lng.toStringAsFixed(5)}';

    Future<void> share() async {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      final link = await showHudSheet<String>(
        context,
        hud: hud,
        builder: (_) => ShareAsSheet(place: place),
      );
      if (link == null) return;
      await SharePlus.instance.share(ShareParams(text: [title, ?place.address, link].join('\n'), sharePositionOrigin: origin));
    }

    void openWebsite() {
      final w = place.website!;
      launchUrl(Uri.parse(w.startsWith('http') ? w : 'https://$w'), mode: LaunchMode.externalApplication);
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 8, 14),
      child: Column(
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
                      const SizedBox(height: 2),
                      Text(
                        place.address!,
                        style: TextStyle(color: hud.muted, fontSize: 14),
                        maxLines: 1,
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
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionPill(hud: hud, icon: Icons.directions_rounded, label: l.directions, primary: true, onTap: onDirections),
                if (onStart != null) ActionPill(hud: hud, icon: Icons.navigation_rounded, label: l.start, onTap: onStart!),
                ActionPill(
                  hud: hud,
                  icon: saved != null ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                  label: saved != null ? l.edit : l.savePlace,
                  onTap: saved != null ? () => onEdit(saved) : onSave,
                ),
                ActionPill(hud: hud, icon: shareIcon, label: l.share, onTap: share),
                if (place.phone != null)
                  ActionPill(
                    hud: hud,
                    icon: Icons.call_rounded,
                    label: l.call,
                    onTap: () => launchUrl(Uri(scheme: 'tel', path: place.phone)),
                  ),
                if (place.website != null) ActionPill(hud: hud, icon: Icons.public_rounded, label: l.website, onTap: openWebsite),
              ],
            ),
          ),
        ],
      ),
    );

    Widget row(IconData icon, String text, {VoidCallback? onTap, String? hint}) => ListTile(
      minTileHeight: 52,
      leading: Icon(icon, color: hud.accentText),
      title: Text(text, style: TextStyle(color: hud.text, fontSize: 15)),
      subtitle: hint == null ? null : Text(hint, style: TextStyle(color: hud.muted, fontSize: 13)),
      onTap: onTap,
    );

    final details = Column(
      children: [
        Divider(height: 1, color: hud.text.withValues(alpha: 0.1)),
        if (place.address != null) row(Icons.place_rounded, place.address!),
        row(
          Icons.my_location_rounded,
          coords,
          hint: l.coordinates,
          onTap: () {
            Clipboard.setData(ClipboardData(text: coords));
            ref.read(toastProvider.notifier).show(l.coordinatesCopied);
          },
        ),
        if (place.phone != null)
          row(
            Icons.call_rounded,
            place.phone!,
            onTap: () => launchUrl(Uri(scheme: 'tel', path: place.phone)),
          ),
        if (place.website != null) row(Icons.public_rounded, place.website!, onTap: openWebsite),
        if (place.social != null)
          row(
            Icons.camera_alt_rounded,
            'Instagram',
            onTap: () => launchUrl(Uri.parse(place.social!), mode: LaunchMode.externalApplication),
          ),
        Divider(height: 1, color: hud.text.withValues(alpha: 0.1)),
        row(
          Icons.open_in_new_rounded,
          l.openInGoogleMaps,
          onTap: () => launchUrl(MapLinks.googleMaps(place.location), mode: LaunchMode.externalApplication),
        ),
        row(
          Icons.open_in_new_rounded,
          l.openInAppleMaps,
          onTap: () =>
              launchUrl(MapLinks.appleMaps(place.location, name: place.isPinned ? null : title), mode: LaunchMode.externalApplication),
        ),
        row(
          Icons.link_rounded,
          l.copyGoogleLink,
          onTap: () {
            Clipboard.setData(ClipboardData(text: MapLinks.googleMaps(place.location).toString()));
            ref.read(toastProvider.notifier).show(l.linkCopied);
          },
        ),
        const SizedBox(height: 8),
      ],
    );

    return MapSheet(hud: hud, header: header, details: details, onDismiss: onClose);
  }
}

/// Rounded action button in a sheet's action row.
class ActionPill extends StatelessWidget {
  const ActionPill({
    super.key,
    required this.hud,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.iconOnly = false,
  });

  final Hud hud;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  /// Label only in tooltip/semantics (tight layouts, large text).
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? hud.onAccent : hud.accentText;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: iconOnly ? label : '',
          excludeFromSemantics: true,
          child: Material(
            color: primary ? hud.accent : Colors.transparent,
            shape: StadiumBorder(side: BorderSide(color: primary ? Colors.transparent : hud.text.withValues(alpha: 0.25))),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: iconOnly ? 12 : 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: fg, size: 20),
                      if (!iconOnly) ...[
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(color: primary ? fg : hud.text, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Share as": which link to send. Returns the text to share.
class ShareAsSheet extends ConsumerWidget {
  const ShareAsSheet({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final at = place.location;
    final name = place.isPinned ? null : place.name;
    final coords = '${at.lat.toStringAsFixed(6)}, ${at.lng.toStringAsFixed(6)}';
    final options = <(IconData, String, String?, String)>[
      (Icons.public_rounded, l.shareOverworldLink, l.shareOverworldHint, placeShareLink(place).toString()),
      (Icons.map_rounded, l.shareGoogleLink, null, MapLinks.googleMaps(at).toString()),
      (Icons.map_outlined, l.shareAppleLink, null, MapLinks.appleMaps(at, name: name).toString()),
      (Icons.layers_rounded, l.shareOsmLink, null, MapLinks.openStreetMap(at).toString()),
      (Icons.my_location_rounded, l.shareCoordinates, coords, coords),
    ];
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HudSectionHeader(hud: hud, text: l.shareAs),
          for (final (icon, title, hint, text) in options)
            ListTile(
              minTileHeight: 56,
              leading: Icon(icon, color: hud.accentText),
              title: Text(
                title,
                style: TextStyle(color: hud.text, fontWeight: FontWeight.w600),
              ),
              subtitle: hint == null ? null : Text(hint, style: TextStyle(color: hud.muted, fontSize: 13)),
              onTap: () => Navigator.of(context).pop(text),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
