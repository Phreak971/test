import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/themes/map_theme.dart';
import 'package:overworld/themes/style_builder.dart';
import 'package:overworld/themes/theme_catalog.dart';

double _contrast(int a, int b) {
  final la = Color(a | 0xFF000000).computeLuminance();
  final lb = Color(b | 0xFF000000).computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final builder = StyleBuilder();

  test('catalog has 15 unique themes with at least one free', () {
    expect(themeCatalog.length, 15);
    expect(themeCatalog.map((t) => t.id).toSet().length, 15);
    expect(themeCatalog.where((t) => !t.isPremium), isNotEmpty);
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
