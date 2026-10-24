import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo.dart';
import '../../core/units.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/content_l10n.dart';
import '../../state/location.dart';
import '../../state/providers.dart';
import '../../themes/icon_painter.dart';
import '../hud.dart';

/// List of saved places. Pops with the tapped [SavedPlace].
class SavedPlacesSheet extends ConsumerWidget {
  const SavedPlacesSheet({super.key, required this.onEdit});

  final ValueChanged<SavedPlace> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final places = [...ref.watch(placesProvider)]
      ..sort((a, b) {
        if (a.isHome != b.isHome) return a.isHome ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    final me = ref.watch(locationProvider.select((s) => s.position));
    final unit = ref.watch(settingsProvider.select((s) => s.unit));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: Text(l.savedTitle, style: displayStyle(hud, 22))),
              ),
              IconButton(
                tooltip: l.close,
                icon: Icon(Icons.close_rounded, color: hud.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        if (places.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
            child: Column(
              children: [
                Icon(Icons.bookmarks_outlined, color: hud.muted, size: 52),
                const SizedBox(height: 12),
                Text(l.savedEmptyTitle, style: displayStyle(hud, 18), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  l.savedEmptyBody,
                  style: TextStyle(color: hud.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: places.length,
              itemBuilder: (context, i) {
                final p = places[i];
                return Dismissible(
                  key: ValueKey(p.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: const Color(0xFFE53935),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete_rounded, color: Colors.white),
                  ),
                  confirmDismiss: (_) => confirmDelete(context, hud, p.name),
                  onDismissed: (_) {
                    ref.read(placesProvider.notifier).remove(p.id);
                    ref.read(toastProvider.notifier).show(l.placeDeleted);
                  },
                  child: ListTile(
                    minTileHeight: 60,
                    leading: CircleAvatar(
                      backgroundColor: (p.isHome ? const Color(0xFF2E7D32) : hud.accent).withValues(alpha: 0.2),
                      child: Icon(placeIconGlyph(p.icon), color: p.isHome ? const Color(0xFF66BB6A) : hud.accentText),
                    ),
                    title: Text(
                      p.name,
                      style: TextStyle(color: hud.text, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [if (me != null) formatDistance(distanceM(me, p.location), unit), ?p.address].join(' · '),
                      style: TextStyle(color: hud.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: l.edit,
                      icon: Icon(Icons.edit_rounded, color: hud.muted),
                      onPressed: () => onEdit(p),
                    ),
                    onTap: () => Navigator.of(context).pop(p),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

Future<bool> confirmDelete(BuildContext context, Hud hud, String name) async {
  final l = L.of(context);
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(l.deleteConfirm(name)),
      actions: [
        adaptiveAction(ctx, label: l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
        adaptiveAction(ctx, label: l.delete, destructive: true, onPressed: () => Navigator.of(ctx).pop(true)),
      ],
    ),
  );
  return ok ?? false;
}

/// Platform-appropriate dialog button.
Widget adaptiveAction(
  BuildContext context, {
  required String label,
  required VoidCallback onPressed,
  bool destructive = false,
  bool isDefault = false,
}) {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoDialogActionCompat(label: label, onPressed: onPressed, destructive: destructive, isDefault: isDefault);
  }
  return TextButton(
    onPressed: onPressed,
    style: destructive ? TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)) : null,
    child: Text(label),
  );
}

/// Minimal Cupertino-style action that avoids importing the whole library in
/// every screen.
class CupertinoDialogActionCompat extends StatelessWidget {
  const CupertinoDialogActionCompat({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.isDefault = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool destructive;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: destructive ? const Color(0xFFFF3B30) : const Color(0xFF0A84FF),
        minimumSize: const Size(44, 44),
      ),
      child: Text(label, style: TextStyle(fontWeight: isDefault ? FontWeight.w700 : FontWeight.w400, fontSize: 17)),
    );
  }
}

/// Create or edit a saved place.
class PlaceEditorSheet extends ConsumerStatefulWidget {
  const PlaceEditorSheet({super.key, this.existing, this.newPlace});

  final SavedPlace? existing;
  final Place? newPlace;

  @override
  ConsumerState<PlaceEditorSheet> createState() => _PlaceEditorSheetState();
}

class _PlaceEditorSheetState extends ConsumerState<PlaceEditorSheet> {
  late final TextEditingController _name;
  late PlaceIcon _icon;
  late bool _home;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final n = widget.newPlace;
    _name = TextEditingController(text: e?.name ?? (n != null && !n.isPinned ? n.name : ''));
    _icon = e?.icon ?? PlaceIcon.star;
    _home = e?.isHome ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final l = L.of(context);
    final notifier = ref.read(placesProvider.notifier);
    final toast = ref.read(toastProvider.notifier);
    final e = widget.existing;
    if (e != null) {
      // Build a single edited value so a rename isn't lost when "home" changes.
      final name = _name.text.trim().isEmpty ? e.name : _name.text.trim();
      final icon = _home ? PlaceIcon.home : (_icon == PlaceIcon.home ? PlaceIcon.star : _icon);
      notifier.update(e.copyWith(name: name, icon: icon, isHome: _home && e.isHome));
      if (_home && !e.isHome) notifier.setHome(e.id);
      toast.show(_home && !e.isHome ? l.homeSet : l.placeUpdated);
    } else {
      final n = widget.newPlace!;
      notifier.add(
        name: _name.text.trim().isEmpty ? (n.isPinned ? l.pinnedLocation : n.name) : _name.text,
        location: n.location,
        icon: _icon,
        address: n.address,
        isHome: _home,
      );
      toast.show(_home ? l.homeSet : l.addedToSaved);
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final isEdit = widget.existing != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: Text(isEdit ? l.editorEditTitle : l.editorNewTitle, style: displayStyle(hud, 22))),
              ),
              IconButton(
                tooltip: l.close,
                icon: Icon(Icons.close_rounded, color: hud.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l.nameLabel,
            style: TextStyle(color: hud.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            autofocus: !isEdit,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 40,
            style: TextStyle(color: hud.text, fontSize: 17),
            decoration: InputDecoration(
              hintText: l.namePlaceholder,
              counterText: '',
              semanticCounterText: '',
              labelText: l.nameLabel,
              floatingLabelBehavior: FloatingLabelBehavior.never,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Text(
            l.iconLabel,
            style: TextStyle(color: hud.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final i in PlaceIcon.values.where((i) => i != PlaceIcon.home))
                Semantics(
                  button: true,
                  selected: !_home && _icon == i,
                  label: placeIconLabel(l, i),
                  hint: _home ? l.homeLocked : null,
                  enabled: !_home,
                  child: InkResponse(
                    onTap: _home
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() => _icon = i);
                          },
                    radius: 28,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !_home && _icon == i ? hud.accent : hud.text.withValues(alpha: 0.08),
                      ),
                      child: Icon(
                        placeIconGlyph(i),
                        color: !_home && _icon == i ? hud.onAccent : hud.text.withValues(alpha: _home ? 0.3 : 1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _home,
            activeTrackColor: hud.accent,
            title: Text(
              l.homeToggle,
              style: TextStyle(color: hud.text, fontWeight: FontWeight.w600),
            ),
            secondary: Icon(Icons.home_rounded, color: hud.accentText),
            onChanged: (v) => setState(() => _home = v),
          ),
          const SizedBox(height: 12),
          PrimaryButton(hud: hud, label: isEdit ? l.saveChanges : l.save, onPressed: _save),
          if (isEdit) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935), minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l.deletePlace),
                onPressed: () async {
                  final nav = Navigator.of(context);
                  if (await confirmDelete(context, hud, widget.existing!.name)) {
                    ref.read(placesProvider.notifier).remove(widget.existing!.id);
                    ref.read(toastProvider.notifier).show(l.placeDeleted);
                    nav.pop(true);
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
