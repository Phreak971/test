import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../hud.dart';
import '../paywall/paywall_screen.dart';

/// Selectable launcher icons. Ids match Android activity-alias names and iOS
/// CFBundleAlternateIcons keys (`AppIcon-<id>`).
const appIcons = <({String id, String name, bool premium})>[
  (id: 'default', name: 'Overworld', premium: false),
  (id: 'neon', name: 'Neon', premium: true),
  (id: 'frontier', name: 'Frontier', premium: true),
  (id: 'blocky', name: 'Voxel', premium: true),
  (id: 'terminal', name: 'Terminal', premium: true),
  (id: 'racer', name: 'Racer', premium: true),
];

Future<bool> applyAppIcon(String id) async {
  if (kIsWeb) return false;
  try {
    if (!await FlutterDynamicIconPlus.supportsAlternateIcons) return false;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    await FlutterDynamicIconPlus.setAlternateIconName(
      iconName: id == 'default' ? (isIOS ? null : 'DEFAULT') : (isIOS ? 'AppIcon-$id' : id),
    );
    return true;
  } on PlatformException {
    return false;
  }
}

class AppIconScreen extends ConsumerWidget {
  const AppIconScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final current = ref.watch(settingsProvider.select((s) => s.appIcon));
    final premium = ref.watch(entitlementProvider).premium;
    return Theme(
      data: buildAppTheme(hud),
      child: Scaffold(
        appBar: AppBar(title: Text(l.appIconTitle)),
        body: Stack(
          children: [
            GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.78,
              children: [
                for (final icon in appIcons)
                  Semantics(
                    button: true,
                    selected: icon.id == current,
                    label: icon.name,
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () async {
                        if (icon.premium && !premium) {
                          Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen()));
                          return;
                        }
                        final toast = ref.read(toastProvider.notifier);
                        final ok = await applyAppIcon(icon.id);
                        if (ok) {
                          HapticFeedback.mediumImpact();
                          ref.read(settingsProvider.notifier).setAppIcon(icon.id);
                          toast.show(l.iconChanged);
                        } else {
                          toast.show(kIsWeb ? l.iconUnsupported : l.iconFailed, kind: ToastKind.error);
                        }
                      },
                      child: Column(
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: icon.id == current ? hud.accent : Colors.transparent, width: 3),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.asset('assets/icons/${icon.id}.png', fit: BoxFit.cover),
                                    if (icon.premium && !premium)
                                      const Align(
                                        alignment: Alignment.topRight,
                                        child: Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            icon.name,
                            style: TextStyle(color: icon.id == current ? hud.accentText : hud.text, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const ToastHost(),
          ],
        ),
      ),
    );
  }
}
