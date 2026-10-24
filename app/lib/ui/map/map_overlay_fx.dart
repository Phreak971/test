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
        final line = Paint()..color = Colors.black.withValues(alpha: 0.22);
        for (var y = 0.0; y < size.height; y += 3) {
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
        }
        _vignette(canvas, rect, Color(palette.accent).withValues(alpha: 0.10), Colors.black.withValues(alpha: 0.55));
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
        _vignette(canvas, rect, Colors.transparent, Colors.black.withValues(alpha: 0.55));
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
        final line = Paint()..color = Colors.black.withValues(alpha: 0.10);
        for (var y = 0.0; y < size.height; y += 4) {
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
        }
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
