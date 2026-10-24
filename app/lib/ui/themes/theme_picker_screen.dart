import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/content_l10n.dart';
import '../../state/location.dart';
import '../../state/providers.dart';
import '../../themes/map_theme.dart';
import '../../themes/theme_catalog.dart';
import '../hud.dart';
import '../map/game_map.dart';
import '../map/map_overlay_fx.dart';
import '../paywall/paywall_screen.dart';
import 'theme_swatch.dart';

/// "Choose your world": live preview on top, grid of themes below.
///
/// With [onboarding] the CTA reads "Start exploring" and calls [onDone]
/// instead of popping.
class ThemePickerScreen extends ConsumerStatefulWidget {
  const ThemePickerScreen({super.key, this.onboarding = false, this.onDone});

  final bool onboarding;
  final VoidCallback? onDone;

  @override
  ConsumerState<ThemePickerScreen> createState() => _ThemePickerScreenState();
}

class _ThemePickerScreenState extends ConsumerState<ThemePickerScreen> {
  late String _themeId;
  late MapVariant _variant;
  final _map = GameMapController();

  @override
  void initState() {
    super.initState();
    final a = ref.read(activeThemeProvider);
    _themeId = a.theme.id;
    _variant = a.variant;
  }

  MapTheme get _theme => themeById(_themeId);

  void _apply() {
    final s = ref.read(settingsProvider.notifier);
    s.selectTheme(_themeId);
    s.setPreferDark(_variant == _theme.baseVariant ? null : _variant == MapVariant.dark);
  }

  void _confirm() {
    final unlocked = ref.read(themeUnlockedProvider(_themeId));
    if (!unlocked) {
      Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen()));
      return;
    }
    HapticFeedback.mediumImpact();
    _apply();
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final premium = ref.watch(entitlementProvider).premium;
    final theme = _theme;
    final hud = Hud.of(theme, _variant);
    final unlocked = !theme.isPremium || premium;
    final center =
        ref.watch(locationProvider.select((s) => s.position)) ??
        (() {
          final c = ref.read(localStoreProvider).loadLastCamera();
          return c == null ? const Geo(40.7580, -73.9855) : Geo(c.lat, c.lng);
        })();
    final mq = MediaQuery.of(context);

    return Theme(
      data: buildAppTheme(hud),
      child: Scaffold(
        backgroundColor: hud.panel.withValues(alpha: 1),
        body: Column(
          children: [
            // Live preview.
            SizedBox(
              height: mq.size.height * 0.4,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: GameMap(
                        controller: _map,
                        theme: theme,
                        variant: _variant,
                        overlay: const MapOverlayData(),
                        initialCenter: center,
                        initialZoom: 15,
                        interactive: false,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: MapOverlayFx(overlay: theme.overlay, palette: theme.palette(_variant)),
                  ),
                  Positioned(
                    left: 12,
                    top: mq.padding.top + 4,
                    child: widget.onboarding
                        ? const SizedBox.shrink()
                        : HudIconButton(hud: hud, icon: Icons.close_rounded, label: l.close, onPressed: () => Navigator.of(context).pop()),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    // Clear of the map attribution control.
                    bottom: 48,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                upper(context, theme.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: displayStyle(hud, 28, color: Color(theme.palette(_variant).label)).copyWith(
                                  shadows: [
                                    Shadow(color: Color(theme.palette(_variant).labelHalo), blurRadius: 6, offset: const Offset(2, 2)),
                                  ],
                                ),
                              ),
                              Text(
                                themeTagline(l, theme.id),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(theme.palette(_variant).label),
                                  fontWeight: FontWeight.w600,
                                  shadows: [Shadow(color: Color(theme.palette(_variant).labelHalo), blurRadius: 4)],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _VariantToggle(hud: hud, value: _variant, onChanged: (v) => setState(() => _variant = v)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(header: true, child: Text(l.mapSelectTitle, style: displayStyle(hud, 22))),
                  ),
                  if (!premium)
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PaywallScreen())),
                      icon: Icon(Icons.lock_open_rounded, color: hud.accentText, size: 18),
                      label: Text(
                        l.unlockAllMaps,
                        style: TextStyle(color: hud.accentText, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: themeCatalog.length,
                itemBuilder: (_, i) {
                  final t = themeCatalog[i];
                  final selected = t.id == _themeId;
                  final locked = t.isPremium && !premium;
                  return _ThemeCard(
                    hud: hud,
                    theme: t,
                    selected: selected,
                    locked: locked,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _themeId = t.id;
                        _variant = t.baseVariant;
                      });
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: PrimaryButton(
                hud: hud,
                icon: unlocked ? null : Icons.lock_rounded,
                label: unlocked ? (widget.onboarding ? l.mapSelectStart : l.done) : l.lockedCta,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantToggle extends StatelessWidget {
  const _VariantToggle({required this.hud, required this.value, required this.onChanged});

  final Hud hud;
  final MapVariant value;
  final ValueChanged<MapVariant> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return HudPanel(
      hud: hud,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in MapVariant.values)
            Semantics(
              button: true,
              selected: v == value,
              label: v == MapVariant.dark ? l.variantDark : l.variantLight,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => onChanged(v),
                borderRadius: BorderRadius.circular(hud.radius.clamp(4, 20)),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: v == value ? hud.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(hud.radius.clamp(4, 20)),
                  ),
                  child: Icon(
                    v == MapVariant.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: v == value ? hud.onAccent : hud.text,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.hud, required this.theme, required this.selected, required this.locked, required this.onTap});

  final Hud hud;
  final MapTheme theme;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cardHud = Hud.of(theme, theme.baseVariant);
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      selected: selected,
      label: '${theme.name}, ${themeGenre(l, theme.id)}${locked ? ', ${l.proLocked}' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: selected ? hud.accent : hud.text.withValues(alpha: 0.1), width: selected ? 3 : 1),
            boxShadow: selected ? [BoxShadow(color: hud.accent.withValues(alpha: 0.35), blurRadius: 12)] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(selected ? 11 : 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ThemeSwatch(theme: theme, variant: theme.baseVariant),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: locked ? Colors.black87 : const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (locked) const Icon(Icons.lock_rounded, color: Colors.white, size: 12),
                              if (locked) const SizedBox(width: 3),
                              Text(
                                locked ? l.proBadge : (theme.isPremium ? '✓' : l.freeBadge),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: cardHud.panel.withValues(alpha: 1),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(theme.name, style: displayStyle(cardHud, 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        themeGenre(l, theme.id),
                        style: TextStyle(color: cardHud.muted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
