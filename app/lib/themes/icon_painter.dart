import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/models.dart';
import 'map_theme.dart';

/// Material glyph for each POI icon id.
const poiGlyphs = <String, IconData>{
  'food': Icons.restaurant,
  'fastfood': Icons.fastfood,
  'coffee': Icons.local_cafe,
  'bar': Icons.local_bar,
  'shop': Icons.shopping_bag,
  'clothes': Icons.checkroom,
  'grocery': Icons.shopping_basket,
  'fuel': Icons.local_gas_station,
  'charging': Icons.ev_station,
  'parking': Icons.local_parking,
  'hotel': Icons.hotel,
  'hospital': Icons.local_hospital,
  'pharmacy': Icons.medication,
  'bank': Icons.attach_money,
  'rail': Icons.subway,
  'bus': Icons.directions_bus,
  'school': Icons.school,
  'park': Icons.park,
  'gym': Icons.fitness_center,
  'hair': Icons.content_cut,
  'car': Icons.garage,
  'cinema': Icons.movie,
  'museum': Icons.account_balance,
  'airport': Icons.flight,
  'worship': Icons.church,
  'dot': Icons.circle,
};

IconData placeIconGlyph(PlaceIcon i) => switch (i) {
  PlaceIcon.star => Icons.star_rounded,
  PlaceIcon.home => Icons.home_rounded,
  PlaceIcon.work => Icons.work_rounded,
  PlaceIcon.food => Icons.restaurant,
  PlaceIcon.coffee => Icons.local_cafe,
  PlaceIcon.bar => Icons.local_bar,
  PlaceIcon.shop => Icons.shopping_bag,
  PlaceIcon.gym => Icons.fitness_center,
  PlaceIcon.heart => Icons.favorite,
  PlaceIcon.flag => Icons.flag,
  PlaceIcon.car => Icons.directions_car,
  PlaceIcon.school => Icons.school,
};

Path shapePath(PoiShape shape, Rect r) {
  final c = r.center;
  final rad = r.width / 2;
  switch (shape) {
    case PoiShape.circle:
    case PoiShape.glyph:
      return Path()..addOval(r);
    case PoiShape.square:
      return Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.18)));
    case PoiShape.pixel:
      return Path()..addRect(r);
    case PoiShape.hexagon:
      final p = Path();
      for (var i = 0; i < 6; i++) {
        final a = math.pi / 6 + i * math.pi / 3;
        final pt = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    case PoiShape.diamond:
      return Path()
        ..moveTo(c.dx, r.top)
        ..lineTo(r.right, c.dy)
        ..lineTo(c.dx, r.bottom)
        ..lineTo(r.left, c.dy)
        ..close();
    case PoiShape.shield:
      return Path()
        ..moveTo(r.left, r.top + r.height * 0.1)
        ..lineTo(c.dx, r.top)
        ..lineTo(r.right, r.top + r.height * 0.1)
        ..lineTo(r.right, r.top + r.height * 0.5)
        ..quadraticBezierTo(r.right, r.bottom - r.height * 0.1, c.dx, r.bottom)
        ..quadraticBezierTo(r.left, r.bottom - r.height * 0.1, r.left, r.top + r.height * 0.5)
        ..close();
  }
}

void _paintGlyph(Canvas canvas, IconData icon, Offset center, double size, Color color, {Color? outline, double outlineWidth = 0}) {
  TextPainter tp(Paint? foreground, Color? c) => TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: size,
        color: foreground == null ? c : null,
        foreground: foreground,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  if (outline != null && outlineWidth > 0) {
    final o = tp(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth
        ..strokeJoin = StrokeJoin.round
        ..color = outline,
      null,
    );
    o.paint(canvas, center - Offset(o.width / 2, o.height / 2));
  }
  final f = tp(null, color);
  f.paint(canvas, center - Offset(f.width / 2, f.height / 2));
}

Future<Uint8List> _toPng(int w, int h, void Function(Canvas c) draw) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  draw(canvas);
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

/// Paints map icons for one theme variant. Images are rendered at 2x and the
/// style scales them with `icon-size`.
class ThemeIconPainter {
  ThemeIconPainter(this.theme, this.palette);

  final MapTheme theme;
  final MapPalette palette;

  static const _poiSize = 64;

  Future<Uint8List> poi(String id) {
    final glyph = poiGlyphs[id] ?? Icons.circle;
    return _toPng(_poiSize, _poiSize, (c) {
      final r = Rect.fromLTWH(6, 6, _poiSize - 12.0, _poiSize - 12.0);
      final fill = Color(palette.poiFill);
      final glyphColor = Color(palette.poiGlyph);
      final stroke = Color(palette.poiStroke);
      if (theme.poiShape == PoiShape.glyph) {
        _paintGlyph(c, glyph, r.center, id == 'dot' ? 16 : 40, glyphColor, outline: fill, outlineWidth: 7);
        return;
      }
      final path = shapePath(theme.poiShape, r);
      c.drawShadow(path, Colors.black, 3, false);
      c.drawPath(path, Paint()..color = fill);
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = stroke,
      );
      _paintGlyph(c, glyph, r.center, id == 'dot' ? 12 : 30, glyphColor);
    });
  }

  /// The player marker; points up (bearing 0) and is rotated by the style.
  Future<Uint8List> puck() {
    const s = 96;
    return _toPng(s, s, (c) {
      final center = const Offset(s / 2, s / 2);
      final accent = Color(palette.accent);
      final dark = Color(palette.casing);
      final light = Colors.white;
      c.drawCircle(center, 40, Paint()..color = accent.withValues(alpha: 0.18));
      final body = Paint()..color = light;
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round
        ..color = dark;
      Path path;
      switch (theme.puck) {
        case PuckShape.arrow:
          path = Path()
            ..moveTo(48, 14)
            ..lineTo(74, 76)
            ..lineTo(48, 62)
            ..lineTo(22, 76)
            ..close();
        case PuckShape.chevron:
          path = Path()
            ..moveTo(48, 12)
            ..lineTo(76, 70)
            ..lineTo(48, 56)
            ..lineTo(20, 70)
            ..close();
          body.color = accent;
        case PuckShape.orb:
          c.drawCircle(center, 22, Paint()..color = accent.withValues(alpha: 0.5));
          path = Path()
            ..moveTo(48, 10)
            ..lineTo(60, 34)
            ..lineTo(36, 34)
            ..close()
            ..addOval(Rect.fromCircle(center: center, radius: 15));
          body.color = accent;
        case PuckShape.block:
          path = Path()
            ..addRect(const Rect.fromLTWH(30, 30, 36, 36))
            ..moveTo(48, 8)
            ..lineTo(62, 26)
            ..lineTo(34, 26)
            ..close();
          body.color = accent;
        case PuckShape.star:
          path = Path();
          for (var i = 0; i < 10; i++) {
            final rr = i.isEven ? 34.0 : 15.0;
            final a = -math.pi / 2 + i * math.pi / 5;
            final pt = center + Offset(rr * math.cos(a), rr * math.sin(a));
            i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          path.close();
          body.color = accent;
        case PuckShape.compass:
          path = Path()
            ..moveTo(48, 10)
            ..lineTo(58, 48)
            ..lineTo(48, 86)
            ..lineTo(38, 48)
            ..close();
          c.drawCircle(
            center,
            26,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = dark,
          );
          body.color = accent;
      }
      c.drawShadow(path, Colors.black, 4, false);
      c.drawPath(path, body);
      c.drawPath(path, edge);
    });
  }

  /// Teardrop map pin with a glyph; used for saved places, dropped pins and
  /// the route destination.
  Future<Uint8List> pin(IconData glyph, {Color? color}) {
    const w = 72, h = 92;
    return _toPng(w, h, (c) {
      final fill = color ?? Color(palette.accent);
      final path = Path()
        ..moveTo(w / 2, h - 4)
        ..cubicTo(w / 2 - 6, h - 22, 6, 46, 6, 34)
        ..arcToPoint(const Offset(w - 6, 34), radius: const Radius.circular(30))
        ..cubicTo(w - 6, 46, w / 2 + 6, h - 22, w / 2, h - 4)
        ..close();
      c.drawShadow(path, Colors.black, 4, false);
      c.drawPath(path, Paint()..color = fill);
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white,
      );
      final onFill = fill.computeLuminance() > 0.55 ? Colors.black : Colors.white;
      _paintGlyph(c, glyph, const Offset(w / 2, 34), 32, onFill);
    });
  }

  /// All images a style needs: name → PNG.
  Future<Map<String, Uint8List>> all({required Iterable<String> poiIds}) async {
    final out = <String, Uint8List>{};
    for (final id in poiIds) {
      out['poi-$id'] = await poi(id);
    }
    out['puck'] = await puck();
    out['pin'] = await pin(Icons.push_pin, color: const Color(0xFFE53935));
    out['dest'] = await pin(Icons.flag, color: Color(palette.route));
    for (final i in PlaceIcon.values) {
      out['place-${i.name}'] = await pin(placeIconGlyph(i), color: i == PlaceIcon.home ? const Color(0xFF2E7D32) : null);
    }
    return out;
  }
}
