import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/icon_painter.dart';
import '../../themes/map_theme.dart';

/// Cheap painted miniature of a theme (no GL context), used in pickers.
class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({super.key, required this.theme, required this.variant});

  final MapTheme theme;
  final MapVariant variant;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _SwatchPainter(theme, theme.palette(variant)), size: Size.infinite),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.theme, this.p);

  final MapTheme theme;
  final MapPalette p;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.drawRect(Offset.zero & s, Paint()..color = Color(p.land));
    // Blocks of landuse.
    final alt = Paint()..color = Color(p.landAlt);
    final rnd = math.Random(theme.id.hashCode);
    for (var i = 0; i < 6; i++) {
      canvas.drawRect(Rect.fromLTWH(rnd.nextDouble() * w, rnd.nextDouble() * h, w * 0.3, h * 0.2), alt);
    }
    // Park + water.
    canvas.drawOval(Rect.fromLTWH(w * 0.05, h * 0.55, w * 0.35, h * 0.3), Paint()..color = Color(p.park));
    final water = Path()
      ..moveTo(w * 0.62, 0)
      ..cubicTo(w * 0.55, h * 0.3, w * 0.9, h * 0.45, w * 0.78, h)
      ..lineTo(w, h)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(water, Paint()..color = Color(p.water));
    canvas.drawPath(water, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Color(p.waterLine));
    // Buildings.
    final b = Paint()..color = Color(p.building);
    for (var i = 0; i < 10; i++) {
      canvas.drawRect(Rect.fromLTWH(rnd.nextDouble() * w * 0.55, rnd.nextDouble() * h, 10, 8), b);
    }
    // Roads: casing then fill.
    void road(List<Offset> pts, int color, double width) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final pt in pts.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      final cap = theme.dashedMinorRoads ? StrokeCap.butt : StrokeCap.round;
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 2.5
        ..strokeCap = cap
        ..color = Color(p.casing));
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = cap
        ..color = Color(color));
    }

    final rw = theme.roadWidth;
    road([Offset(0, h * 0.3), Offset(w * 0.5, h * 0.42), Offset(w, h * 0.35)], p.motorway, 5 * rw);
    road([Offset(w * 0.3, 0), Offset(w * 0.34, h)], p.major, 3.5 * rw);
    road([Offset(0, h * 0.75), Offset(w * 0.6, h * 0.7)], p.minor, 2.2 * rw);
    road([Offset(w * 0.12, 0), Offset(w * 0.18, h * 0.6)], p.minor, 2.2 * rw);
    // Route.
    road([Offset(w * 0.34, h * 0.9), Offset(w * 0.33, h * 0.42), Offset(w * 0.55, h * 0.4)], p.route, 3.2);
    // POI badges.
    for (final (i, id) in ['food', 'coffee', 'fuel'].indexed) {
      final c = Offset(w * (0.18 + i * 0.2), h * (0.2 + (i % 2) * 0.35));
      final r = Rect.fromCircle(center: c, radius: 8);
      if (theme.poiShape == PoiShape.glyph) {
        canvas.drawCircle(c, 3.5, Paint()..color = Color(p.poiGlyph));
        continue;
      }
      final path = shapePath(theme.poiShape, r);
      canvas.drawPath(path, Paint()..color = Color(p.poiFill));
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color(p.poiStroke));
      canvas.drawCircle(c, 2.5, Paint()..color = Color(p.poiGlyph));
      if (id.isEmpty) break;
    }
    // Player marker.
    final puck = Path()
      ..moveTo(w * 0.34, h * 0.84)
      ..lineTo(w * 0.34 + 7, h * 0.84 + 16)
      ..lineTo(w * 0.34, h * 0.84 + 12)
      ..lineTo(w * 0.34 - 7, h * 0.84 + 16)
      ..close();
    canvas.drawPath(puck, Paint()..color = Color(p.accent));
    canvas.drawPath(puck, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Color(p.casing));
  }

  @override
  bool shouldRepaint(_SwatchPainter old) => old.theme.id != theme.id || old.p != p;
}
