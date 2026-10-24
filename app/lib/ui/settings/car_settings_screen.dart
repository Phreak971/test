import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../themes/map_theme.dart';
import '../../themes/theme_catalog.dart';
import '../hud.dart';
import '../paywall/paywall_screen.dart';
import '../themes/theme_swatch.dart';

/// Light/dark map styles for CarPlay / Android Auto.
class CarSettingsScreen extends ConsumerWidget {
  const CarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final hud = ref.watch(hudProvider);
    final s = ref.watch(settingsProvider);
    final premium = ref.watch(entitlementProvider).premium;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final n = ref.read(settingsProvider.notifier);

    Widget picker(String title, String selectedId, MapVariant variant, ValueChanged<String> onPick) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HudSectionHeader(hud: hud, text: title),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: themeCatalog.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final t = themeCatalog[i];
                final selected = t.id == selectedId;
                final locked = t.isPremium && !premium;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: '${t.name}${selected ? ', ${l.currentlyActive}' : ''}${locked ? ', ${l.proLocked}' : ''}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: locked
                        ? () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen()))
                        : () {
                            onPick(t.id);
                            ref.read(toastProvider.notifier).show(l.carUpdated);
                          },
                    child: Opacity(
                      opacity: locked ? 0.45 : 1,
                      child: SizedBox(
                        width: 120,
                        child: Column(
                          children: [
                            Container(
                              height: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: selected ? hud.accent : Colors.transparent, width: 3),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ThemeSwatch(theme: t, variant: variant),
                                    if (locked) const Center(child: Icon(Icons.lock_rounded, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.name,
                              style: TextStyle(color: selected ? hud.accentText : hud.text, fontWeight: FontWeight.w700, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Theme(
      data: buildAppTheme(hud),
      child: Scaffold(
        appBar: AppBar(title: Text(isIOS ? l.carSettingsIos : l.carSettingsAndroid)),
        body: Stack(
          children: [
            ListView(
              children: [
                picker(l.carLightStyle, s.carLightThemeId, MapVariant.light, n.setCarLight),
                picker(l.carDarkStyle, s.carDarkThemeId, MapVariant.dark, n.setCarDark),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: s.carAlwaysDark,
                  activeTrackColor: hud.accent,
                  secondary: Icon(Icons.dark_mode_rounded, color: hud.accentText),
                  title: Text(
                    l.carAlwaysDark,
                    style: TextStyle(color: hud.text, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (v) {
                    n.setCarAlwaysDark(v);
                    ref.read(toastProvider.notifier).show(l.carUpdated);
                  },
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
