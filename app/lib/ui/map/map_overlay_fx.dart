import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/map_theme.dart';

/// Decorative full-screen layer above the map (never intercepts touches).
class MapOverlayFx extends StatelessWidget {
  const MapOverlayFx({super.key, required this.overlay, required this.palette});

  final MapOverlay overlay;
  final MapPalette palette;

  @override
  Widget build(BuildContext context) {
    if (overlay == MapOverlay.none) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(painter: _FxPainter(overlay, palette), size: Size.infinite),
        ),
      ),
    );
  }
}

class _FxPainter extends CustomPainter {
  _FxPainter(this.overlay, this.palette);

  final MapOverlay overlay;
  final MapPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    switch (overlay) {
      case MapOverlay.none:
        return;
      case MapOverlay.scanlines:
        final line = Paint()..color = Colors.black.withValues(alpha: palette.isDark ? 0.22 : 0.07);
        for (var y = 0.0; y < size.height; y += 3) {
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
        }
        _vignette(
          canvas,
          rect,
          Color(palette.accent).withValues(alpha: 0.10),
          Colors.black.withValues(alpha: palette.isDark ? 0.55 : 0.18),
        );
      case MapOverlay.parchment:
        // Warm wash, fibre speckle, burnt edges.
        canvas.drawRect(rect, Paint()..color = const Color(0xFF8B5A2B).withValues(alpha: 0.06));
        final rnd = math.Random(7);
        final speck = Paint();
        for (var i = 0; i < 900; i++) {
          speck.color = const Color(0xFF5A3A1A).withValues(alpha: rnd.nextDouble() * 0.06);
          canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height), rnd.nextDouble() * 1.6, speck);
        }
        _vignette(canvas, rect, Colors.transparent, const Color(0xFF3A2410).withValues(alpha: 0.45));
      case MapOverlay.vignette:
        // Light maps get a faint vignette; a strong one reads as a grey smudge.
        _vignette(canvas, rect, Colors.transparent, Colors.black.withValues(alpha: palette.isDark ? 0.55 : 0.16));
      case MapOverlay.grid:
        final p = Paint()
          ..color = Color(palette.label).withValues(alpha: 0.10)
          ..strokeWidth = 1;
        const step = 64.0;
        for (var x = 0.0; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (var y = 0.0; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        // Grid references along the edges, like a recon sheet.
        final tp = TextPainter(textDirection: TextDirection.ltr);
        final style = TextStyle(
          color: Color(palette.label).withValues(alpha: 0.45),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        );
        var col = 0;
        for (var x = 0.0; x < size.width; x += step, col++) {
          tp.text = TextSpan(text: String.fromCharCode(65 + col % 26), style: style);
          tp.layout();
          tp.paint(canvas, Offset(x + 4, size.height - 120));
        }
        _vignette(canvas, rect, Colors.transparent, Colors.black.withValues(alpha: 0.3));
      case MapOverlay.pixelGrid:
        final p = Paint()..color = Colors.black.withValues(alpha: 0.05);
        const s = 8.0;
        for (var x = 0.0; x < size.width; x += s) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), p);
        }
        for (var y = 0.0; y < size.height; y += s) {
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
        }
      case MapOverlay.neon:
        final glow = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(palette.accent).withValues(alpha: 0.10), Colors.transparent, Color(palette.route).withValues(alpha: 0.10)],
          ).createShader(rect);
        canvas.drawRect(rect, glow);
        final line = Paint()..color = Colors.black.withValues(alpha: palette.isDark ? 0.10 : 0.04);
        for (var y = 0.0; y < size.height; y += 4) {
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
        }
      case MapOverlay.starfield:
        // Stars only toward the edges so the map centre stays readable.
        _vignette(canvas, rect, Colors.transparent, Colors.black.withValues(alpha: palette.isDark ? 0.6 : 0.2));
        final rnd = math.Random(42);
        final star = Paint();
        final c = rect.center;
        final reach = size.shortestSide * 0.5;
        for (var i = 0; i < 260; i++) {
          final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
          final edge = ((p - c).distance / reach - 0.7).clamp(0.0, 1.0);
          if (edge == 0) continue;
          star.color = Colors.white.withValues(alpha: edge * (0.25 + rnd.nextDouble() * 0.55));
          canvas.drawCircle(p, 0.5 + rnd.nextDouble() * 1.1, star);
        }
      case MapOverlay.hologram:
        final tint = Color(palette.accent);
        final line = Paint()..color = tint.withValues(alpha: 0.06);
        for (var y = 0.0; y < size.height; y += 3) {
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
        }
        // Projector glow from the bottom edge.
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [tint.withValues(alpha: 0.16), Colors.transparent],
              stops: const [0, 0.45],
            ).createShader(rect),
        );
        _vignette(canvas, rect, Colors.transparent, Colors.black.withValues(alpha: 0.5));
      case MapOverlay.embers:
        _vignette(canvas, rect, Colors.transparent, const Color(0xFF3A0A00).withValues(alpha: 0.6));
        final rnd = math.Random(13);
        final ember = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
        for (var i = 0; i < 70; i++) {
          // Denser near the bottom, like rising sparks.
          final y = size.height * (1 - math.pow(rnd.nextDouble(), 2) * 0.55);
          final p = Offset(rnd.nextDouble() * size.width, y);
          ember.color = Color.lerp(
            const Color(0xFFFF6A1A),
            const Color(0xFFFFD54F),
            rnd.nextDouble(),
          )!.withValues(alpha: 0.25 + rnd.nextDouble() * 0.35);
          canvas.drawCircle(p, 0.8 + rnd.nextDouble() * 1.6, ember);
        }
      case MapOverlay.mist:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFFFFF8E1).withValues(alpha: 0.35), Colors.transparent, Colors.white.withValues(alpha: 0.18)],
              stops: const [0, 0.35, 1],
            ).createShader(rect),
        );
        _vignette(canvas, rect, Colors.transparent, const Color(0xFF2F4A3A).withValues(alpha: palette.isDark ? 0.45 : 0.14));
      case MapOverlay.candlelight:
        _vignette(
          canvas,
          rect,
          const Color(0xFFFFB74D).withValues(alpha: palette.isDark ? 0.07 : 0.04),
          const Color(0xFF0A0510).withValues(alpha: palette.isDark ? 0.6 : 0.2),
        );
    }
  }

  void _vignette(Canvas canvas, Rect rect, Color inner, Color outer) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [inner, inner.withValues(alpha: 0), outer],
          stops: const [0, 0.6, 1],
          radius: 0.85,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_FxPainter old) => old.overlay != overlay || old.palette != palette;
}
