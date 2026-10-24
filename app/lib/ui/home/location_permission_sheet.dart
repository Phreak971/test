import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/location.dart';
import '../../state/providers.dart';
import '../hud.dart';

/// Explains location use before the system prompt (HIG: prime, then ask),
/// and offers Settings when access was previously denied.
class LocationPermissionSheet extends ConsumerWidget {
  const LocationPermissionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final perm = ref.watch(locationProvider.select((s) => s.permission));
    final blocked = perm == LocPermission.deniedForever || perm == LocPermission.serviceOff;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: hud.accent.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(Icons.my_location_rounded, color: hud.accentText, size: 38),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              blocked ? (perm == LocPermission.serviceOff ? l.locationOff : l.locationDenied) : l.obLocationTitle,
              style: displayStyle(hud, 24),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            blocked ? l.locationDeniedBody : l.obLocationBody,
            style: TextStyle(color: hud.muted, fontSize: 15, height: 1.35),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            hud: hud,
            label: blocked ? l.openSettings : l.obAllowLocation,
            icon: blocked ? Icons.settings_rounded : Icons.near_me_rounded,
            onPressed: () async {
              final nav = Navigator.of(context);
              final n = ref.read(locationProvider.notifier);
              if (blocked) {
                await n.openSettings();
              } else {
                await n.request();
              }
              if (nav.mounted) nav.pop();
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () {
              ref.read(settingsProvider.notifier).dismissLocationPrompt();
              Navigator.of(context).pop();
            },
            child: Text(
              l.obSkipLocation,
              style: TextStyle(color: hud.muted, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
