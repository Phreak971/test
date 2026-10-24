import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../themes/map_theme.dart';

const displayFont = 'ChakraPetch';

/// Locale-aware uppercase (Dart's toUpperCase ignores Turkish dotted İ).
String upper(BuildContext context, String s) {
  final lang = Localizations.maybeLocaleOf(context)?.languageCode;
  if (lang == 'tr' || lang == 'az') s = s.replaceAll('i', 'İ').replaceAll('ı', 'I');
  return s.toUpperCase();
}

/// Platform-appropriate share glyph.
IconData get shareIcon => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS
    ? Icons.ios_share_rounded
    : Icons.share_rounded;

/// Chrome colours for the active map theme, so every panel matches the world.
///
/// Every foreground colour is contrast-checked against the opaque panel so
/// derived light/dark variants stay legible (WCAG AA for text).
class Hud {
  Hud({required Color panel, required this.text, required this.accent, required this.radius, required this.isDark})
    : panel = panel.withValues(alpha: panel.a < 0.97 ? 0.97 : panel.a);

  factory Hud.of(MapTheme t, MapVariant v) {
    final p = t.palette(v);
    return Hud(
      panel: Color(p.hudPanel),
      text: Color(p.hudText),
      accent: Color(p.accent),
      radius: t.hudCorner,
      isDark: Color(p.hudPanel).computeLuminance() < 0.4,
    );
  }

  /// Panel fill (near-opaque: map labels must never show through text).
  final Color panel;
  final Color text;

  /// Brand accent for fills (buttons, banners, selection), paired with
  /// [onAccent]. Use [accentText] when the accent is foreground on a panel.
  final Color accent;
  final double radius;
  final bool isDark;

  Color get panelOpaque => panel.withValues(alpha: 1);
  int get _bg => panelOpaque.toARGB32();

  late final Color accentText = Color(ensureContrast(accent.toARGB32(), _bg, 4.5));
  late final Color muted = Color(ensureContrast(Color.alphaBlend(text.withValues(alpha: 0.7), panelOpaque).toARGB32(), _bg, 4.5));
  late final Color danger = Color(ensureContrast(0xFFE53935, _bg, 4.5));
  Color get divider => text.withValues(alpha: 0.12);

  /// Black or white, whichever reads better on [accent].
  late final Color onAccent = contrastRatio(accent.toARGB32(), 0xFF000000) >= contrastRatio(accent.toARGB32(), 0xFFFFFFFF)
      ? Colors.black
      : Colors.white;
  Color get surface => Color.alphaBlend(text.withValues(alpha: 0.06), panelOpaque);
}

final hudProvider = Provider<Hud>((ref) {
  final a = ref.watch(activeThemeProvider);
  return Hud.of(a.theme, a.variant);
});

ThemeData buildAppTheme(Hud hud) {
  final scheme = ColorScheme.fromSeed(
    seedColor: hud.accent,
    brightness: hud.isDark ? Brightness.dark : Brightness.light,
  ).copyWith(primary: hud.accent, onPrimary: hud.onAccent, surface: hud.panel.withValues(alpha: 1), onSurface: hud.text);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme.apply(bodyColor: hud.text, displayColor: hud.text),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: hud.text,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w700, fontSize: 20, color: hud.text),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.iOS: CupertinoPageTransitionsBuilder(), TargetPlatform.android: PredictiveBackPageTransitionsBuilder()},
    ),
    dividerTheme: DividerThemeData(color: hud.divider, space: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: hud.surface,
      titleTextStyle: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w700, fontSize: 20, color: hud.text),
      contentTextStyle: TextStyle(color: hud.text, fontSize: 15, height: 1.35),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: hud.accent,
        selectedForegroundColor: hud.onAccent,
        foregroundColor: hud.text,
        side: BorderSide(color: hud.text.withValues(alpha: 0.25)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: hud.accentText, minimumSize: const Size(48, 44)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? hud.onAccent : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? hud.accent : null),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: hud.text.withValues(alpha: 0.07),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      hintStyle: TextStyle(color: hud.muted),
    ),
  );
}

TextStyle displayStyle(Hud hud, double size, {FontWeight weight = FontWeight.w700, Color? color}) =>
    TextStyle(fontFamily: displayFont, fontWeight: weight, fontSize: size, color: color ?? hud.text, height: 1.15);

/// Frosted, theme-tinted panel.
class HudPanel extends StatelessWidget {
  const HudPanel({super.key, required this.hud, required this.child, this.padding = const EdgeInsets.all(12), this.radius});

  final Hud hud;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? hud.radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: hud.panel,
            borderRadius: r,
            border: Border.all(color: hud.text.withValues(alpha: 0.12)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Square HUD button with a 48pt hit target, tooltip and semantics label.
class HudIconButton extends StatelessWidget {
  const HudIconButton({
    super.key,
    required this.hud,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.size = 48,
    this.badge,
  });

  final Hud hud;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final double size;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final fg = active ? hud.onAccent : hud.text;
    return Semantics(
      button: true,
      label: label,
      selected: active,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox(
          width: size,
          height: size,
          child: Material(
            color: active ? hud.accent : hud.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(hud.radius.clamp(0, size / 2)),
              side: BorderSide(color: hud.text.withValues(alpha: 0.14)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onPressed!();
                    },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: fg, size: size * 0.5),
                  if (badge != null) Positioned(top: 4, right: 4, child: badge!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.hud,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
  });

  final Hud hud;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: hud.onAccent))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  style: displayStyle(hud, 17, color: hud.onAccent),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
    final btn = FilledButton(
      onPressed: busy || onPressed == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed!();
            },
      style: FilledButton.styleFrom(
        backgroundColor: hud.accent,
        foregroundColor: hud.onAccent,
        disabledBackgroundColor: hud.accent.withValues(alpha: 0.4),
        minimumSize: const Size(64, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(hud.radius.clamp(4, 27))),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.hud, required this.label, required this.onPressed, this.icon, this.expand = true});

  final Hud hud;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: hud.text,
        minimumSize: const Size(64, 50),
        side: BorderSide(color: hud.text.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(hud.radius.clamp(4, 25))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              style: displayStyle(hud, 16, weight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Modal bottom sheet in HUD style: drag handle, swipe-to-dismiss, safe area.
Future<T?> showHudSheet<T>(
  BuildContext context, {
  required Hud hud,
  required WidgetBuilder builder,
  bool expand = false,
  double initialSize = 0.5,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (ctx) {
      final content = Container(
        decoration: BoxDecoration(
          color: hud.panel.withValues(alpha: 0.98),
          borderRadius: BorderRadius.vertical(top: Radius.circular(hud.radius.clamp(12, 28))),
          border: Border(top: BorderSide(color: hud.text.withValues(alpha: 0.12))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: MaterialLocalizations.of(ctx).modalBarrierDismissLabel,
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: hud.text.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Flexible(child: builder(ctx)),
          ],
        ),
      );
      if (!expand) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: content,
        );
      }
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: FractionallySizedBox(heightFactor: 0.92, alignment: Alignment.bottomCenter, child: content),
      );
    },
  );
}

/// Section header used in sheets and settings.
class HudSectionHeader extends StatelessWidget {
  const HudSectionHeader({super.key, required this.hud, required this.text, this.trailing});

  final Hud hud;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                upper(context, text),
                style: displayStyle(hud, 13, weight: FontWeight.w600, color: hud.muted).copyWith(letterSpacing: 1.2),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Floating toast listening to [toastProvider].
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toast = ref.watch(toastProvider);
    final hud = ref.watch(hudProvider);
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => SlideTransition(
              position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(a),
              child: FadeTransition(opacity: a, child: c),
            ),
            child: toast == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(toast.id),
                    padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: HudPanel(
                        hud: hud,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              switch (toast.kind) {
                                ToastKind.success => Icons.check_circle,
                                ToastKind.error => Icons.error,
                                ToastKind.info => Icons.info,
                              },
                              color: toast.kind == ToastKind.error ? hud.danger : hud.accentText,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(toast.text, style: displayStyle(hud, 15, weight: FontWeight.w600)),
                            ),
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
