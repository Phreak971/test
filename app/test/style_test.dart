import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/themes/icon_painter.dart';
import 'package:overworld/themes/map_theme.dart';
import 'package:overworld/themes/style_builder.dart';
import 'package:overworld/themes/theme_catalog.dart';

double _contrast(int a, int b) {
  final la = Color(a | 0xFF000000).computeLuminance();
  final lb = Color(b | 0xFF000000).computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// CIE76 colour difference (perceptual: counts hue, not just luminance).
double _deltaE(int a, int b) {
  List<double> lab(int c) {
    double ch(int v) {
      final x = v / 255;
      return x <= 0.04045 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = ch((c >> 16) & 0xFF), g = ch((c >> 8) & 0xFF), bl = ch(c & 0xFF);
    final x = (r * 0.4124 + g * 0.3576 + bl * 0.1805) / 0.95047;
    final y = r * 0.2126 + g * 0.7152 + bl * 0.0722;
    final z = (r * 0.0193 + g * 0.1192 + bl * 0.9505) / 1.08883;
    double f(double t) => t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
    return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
  }

  final p = lab(a), q = lab(b);
  return math.sqrt(math.pow(p[0] - q[0], 2) + math.pow(p[1] - q[1], 2) + math.pow(p[2] - q[2], 2));
}

void main() {
  final builder = StyleBuilder();

  test('catalog has 15 unique themes', () {
    expect(themeCatalog.length, 15);
    expect(themeCatalog.map((t) => t.id).toSet().length, 15);
    expect(themeById('nope').id, themeCatalog.first.id);
  });

  for (final t in themeCatalog) {
    for (final v in MapVariant.values) {
      test('style ${t.id}/${v.name} is well-formed', () {
        final style = builder.build(t, v);
        expect(style['version'], 8);
        final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
        final ids = layers.map((l) => l['id']).toList();
        expect(ids.toSet().length, ids.length, reason: 'duplicate layer ids');
        expect(ids.first, 'background');
        // App overlay layers exist and the puck draws last.
        for (final id in [AppLayers.routeLine, AppLayers.places, AppLayers.user, AppLayers.poi]) {
          expect(ids, contains(id));
        }
        expect(ids.last, AppLayers.user);
        // Every layer source exists.
        final sources = (style['sources'] as Map).keys.toSet();
        for (final l in layers.where((l) => l.containsKey('source'))) {
          expect(sources, contains(l['source']));
        }
        // Valid JSON roundtrip.
        expect(jsonDecode(jsonEncode(style)), isA<Map<String, dynamic>>());

        // Export for the MapLibre style validator and web visual QA.
        final dir = Directory('build/styles')..createSync(recursive: true);
        File('${dir.path}/${t.id}-${v.name}.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(style));
      });

      test('palette ${t.id}/${v.name} keeps labels legible', () {
        final p = t.palette(v);
        expect(_contrast(p.label, p.labelHalo), greaterThanOrEqualTo(3.0), reason: 'label vs halo');
        expect(_contrast(p.hudText, p.hudPanel), greaterThanOrEqualTo(4.5), reason: 'HUD text vs panel');
        expect(_contrast(p.route, p.land), greaterThanOrEqualTo(1.6), reason: 'route visible on land');
        expect(_deltaE(p.water, p.land), greaterThanOrEqualTo(8), reason: 'water distinct from land');
        expect(_deltaE(p.park, p.land), greaterThanOrEqualTo(4), reason: 'parks distinct from land');
        final puck = puckColors(p);
        expect(_contrast(puck.accent.toARGB32(), p.land), greaterThanOrEqualTo(3), reason: 'puck visible');
        if (v == MapVariant.dark) {
          expect(Color(p.hudPanel | 0xFF000000).computeLuminance(), lessThan(0.2), reason: 'dark variants use dark chrome');
        }
      });
    }
  }

  test('inverted palette flips darkness', () {
    for (final t in themeCatalog) {
      expect(t.base.inverted().isDark, isNot(t.base.isDark), reason: t.id);
    }
  });

  test('every poi icon referenced by the class map is generated', () {
    for (final icon in poiClassIcons.values) {
      expect(poiIconIds, contains(icon));
    }
    expect(poiIconIds, contains('dot'));
  });
}
