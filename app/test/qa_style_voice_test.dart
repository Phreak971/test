// QA: style builder invariants for every theme/variant, palette inversion,
// voice phrase generation for all maneuvers x languages x personas x stages,
// and timing of StyleBuilder.build. `// BUG:` tests fail until fixed.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/core/units.dart';
import 'package:overworld/data/models.dart';
import 'package:overworld/nav/navigation_engine.dart';
import 'package:overworld/nav/voice.dart';
import 'package:overworld/themes/map_theme.dart';
import 'package:overworld/themes/style_builder.dart';
import 'package:overworld/themes/theme_catalog.dart';

/// Visits every JSON node.
void _walk(Object? node, void Function(Object? n) f) {
  f(node);
  if (node is Map) {
    for (final v in node.values) {
      _walk(v, f);
    }
  } else if (node is List) {
    for (final v in node) {
      _walk(v, f);
    }
  }
}

/// Image names the runtime registers (mirrors ThemeIconPainter.all).
final _registeredImages = {
  for (final id in poiIconIds) AppLayers.poiIcon(id),
  AppLayers.puck,
  AppLayers.pinIcon,
  AppLayers.destIcon,
  for (final i in PlaceIcon.values) AppLayers.placeIcon(i.name),
};

const _langs = ['en', 'de', 'fr', 'it', 'es', 'tr', 'pt', 'zh', ''];

void main() {
  final builder = StyleBuilder();

  group('style builder invariants', () {
    for (final t in themeCatalog) {
      for (final v in MapVariant.values) {
        test('${t.id}/${v.name}', () {
          final style = builder.build(t, v);
          final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
          final sources = (style['sources'] as Map).cast<String, dynamic>();

          // 1. All numbers finite (NaN/Infinity cannot be JSON-encoded and
          //    would break MapLibre style parsing).
          _walk(style, (n) {
            if (n is double) expect(n.isFinite, isTrue);
          });
          expect(() => builder.buildJson(t, v), returnsNormally);

          // 2. Every colour string is a valid #rrggbb or rgba().
          _walk(style, (n) {
            if (n is String && (n.startsWith('#') || n.startsWith('rgba('))) {
              expect(RegExp(r'^(#[0-9a-f]{6}|rgba\(\d{1,3},\d{1,3},\d{1,3},[01]\.\d{3}\))$').hasMatch(n), isTrue, reason: n);
            }
          });

          // 3. `match` expressions: label lists have no duplicates and there
          //    is an odd arg count (input, label/output pairs..., fallback).
          _walk(style, (n) {
            if (n is List && n.isNotEmpty && n.first == 'match') {
              expect((n.length - 2) % 2, 1, reason: 'match needs pairs + fallback: $n');
              final labels = <Object?>[];
              for (var i = 2; i < n.length - 1; i += 2) {
                final l = n[i];
                if (l is List) {
                  labels.addAll(l);
                } else {
                  labels.add(l);
                }
              }
              expect(labels.toSet().length, labels.length, reason: 'duplicate match labels in $n');
            }
          });

          // 4. Every constant icon-image resolves to a registered image; the
          //    poi `concat` resolves for every class and the fallback.
          for (final l in layers) {
            final img = (l['layout'] as Map?)?['icon-image'];
            if (img is String) expect(_registeredImages, contains(img), reason: '${l['id']} -> $img');
          }
          final poi = layers.firstWhere((l) => l['id'] == AppLayers.poi);
          final concat = (poi['layout'] as Map)['icon-image'] as List;
          final match = concat[2] as List;
          final outputs = [for (var i = 3; i < match.length - 1; i += 2) match[i], match.last];
          for (final out in outputs) {
            expect(_registeredImages, contains('${concat[1]}$out'), reason: 'poi output $out');
          }

          // 5. Vector layers reference the vector source + a source-layer;
          //    app layers reference geojson sources.
          for (final l in layers.where((l) => l.containsKey('source'))) {
            final src = sources[l['source']] as Map;
            if (src['type'] == 'vector') {
              expect(l['source-layer'], isA<String>(), reason: l['id'] as String);
            } else {
              expect(l.containsKey('source-layer'), isFalse, reason: l['id'] as String);
            }
          }

          // 6. minzoom within 0..24.
          for (final l in layers) {
            final mz = l['minzoom'];
            if (mz != null) expect((mz as num) >= 0 && mz <= 24, isTrue);
          }

          // 7. Route draws below labels; overlay symbols above everything.
          final ids = layers.map((l) => l['id']).toList();
          expect(ids.indexOf(AppLayers.routeLine), lessThan(ids.indexOf('road-label')));
          expect(ids.indexOf(AppLayers.places), greaterThan(ids.indexOf('place-label')));

          // 8. Deterministic: same input -> identical JSON.
          expect(builder.buildJson(t, v), jsonEncode(builder.build(t, v)));
        });
      }
    }

    test('poi match covers every class in poiClassIcons', () {
      final style = builder.build(themeCatalog.first, MapVariant.light);
      final poi = (style['layers'] as List).cast<Map<String, dynamic>>().firstWhere((l) => l['id'] == AppLayers.poi);
      final match = ((poi['layout'] as Map)['icon-image'] as List)[2] as List;
      for (final k in poiClassIcons.keys) {
        expect(match, contains(k));
      }
    });
  });

  group('palette inversion', () {
    for (final t in themeCatalog) {
      test('${t.id}: double inversion returns to the base darkness and keeps contrast', () {
        final once = t.base.inverted();
        final twice = once.inverted();
        expect(twice.isDark, t.base.isDark);
        for (final p in [once, twice]) {
          expect(contrastRatio(p.label, p.labelHalo), greaterThanOrEqualTo(4.5));
          expect(contrastRatio(p.roadLabel, p.roadLabelHalo), greaterThanOrEqualTo(4.5));
          expect(contrastRatio(p.hudText, p.hudPanel), greaterThanOrEqualTo(4.5));
          expect(contrastRatio(p.route, p.land), greaterThanOrEqualTo(2.5));
          expect(contrastRatio(p.motorway, p.land), greaterThanOrEqualTo(2.5));
        }
        // Hue-preserving: accent/poi colours are untouched.
        expect(once.accent, t.base.accent);
        expect(once.poiFill, t.base.poiFill);
        // Pure function: repeated calls agree.
        expect(t.base.inverted().land, once.land);
      });

      test('${t.id}: palette(baseVariant) is the hand-tuned base (identity)', () {
        expect(identical(t.palette(t.baseVariant), t.base), isTrue);
      });
    }

    test('ensureContrast terminates on extreme inputs', () {
      for (final fg in [0xFF000000, 0xFFFFFFFF, 0xFF808080, 0x00000000]) {
        for (final bg in [0xFF000000, 0xFFFFFFFF, 0xFF777777]) {
          final c = ensureContrast(fg, bg, 21);
          expect(c, isA<int>());
        }
      }
    });
  });

  group('voice phrases', () {
    RouteStep step(ManeuverKind k, {String street = 'Main Street', int? exit}) => RouteStep(
      kind: k,
      location: const Geo(0, 0),
      distanceM: 100,
      durationS: 10,
      streetName: street,
      geometry: const [Geo(0, 0), Geo(0, 0.001)],
      roundaboutExit: exit,
    );

    test('all maneuvers x languages x personas x stages x units produce clean text', () {
      var n = 0;
      for (final k in ManeuverKind.values) {
        for (final lang in _langs) {
          for (final p in voicePersonas) {
            for (final stage in CueStage.values) {
              for (final unit in DistanceUnit.values) {
                for (final d in [0.0, 3.0, 49.0, 420.0, 1499.0, 25000.0]) {
                  for (final street in ['', 'Main Street']) {
                    final s = phraseFor(
                      VoiceCue(
                        step: step(k, street: street),
                        stage: stage,
                        distanceM: d,
                        stepIndex: 3,
                      ),
                      p,
                      unit,
                      lang,
                      seed: 3,
                    );
                    n++;
                    expect(s.trim(), isNotEmpty);
                    expect(s, isNot(contains('{')));
                    expect(s, isNot(contains('}')));
                    expect(s, isNot(contains('null')));
                    expect(s, isNot(contains('  ')), reason: s);
                    expect(s, isNot(contains('NaN')));
                    expect(s.trim(), s, reason: 'leading/trailing whitespace: "$s"');
                  }
                }
              }
            }
          }
        }
      }
      // ignore: avoid_print
      print('voice: $n phrases checked');
    });

    test('phrases are deterministic for the same seed', () {
      for (final p in voicePersonas) {
        final cue = VoiceCue(step: step(ManeuverKind.left), stage: CueStage.approach, distanceM: 300, stepIndex: 2);
        expect(phraseFor(cue, p, DistanceUnit.metric, 'en', seed: 9), phraseFor(cue, p, DistanceUnit.metric, 'en', seed: 9));
      }
    });

    test('street names with template tokens or very long names are spoken safely', () {
      final s = phraseFor(
        VoiceCue(
          step: step(ManeuverKind.right, street: 'X' * 5000),
          stage: CueStage.now,
          distanceM: 30,
          stepIndex: 1,
        ),
        personaById('classic'),
        DistanceUnit.metric,
        'en',
      );
      expect(s.length, greaterThan(5000));
    });

    test('roundabout exits null/1..5 in every language', () {
      for (final lang in _langs) {
        for (final e in [null, 1, 2, 3, 4, 5]) {
          final s = phraseFor(
            VoiceCue(
              step: step(ManeuverKind.roundabout, street: '', exit: e),
              stage: CueStage.now,
              distanceM: 30,
              stepIndex: 1,
            ),
            personaById('classic'),
            DistanceUnit.metric,
            lang,
          );
          expect(s, isNotEmpty);
        }
      }
    });

    // BUG (P2): English ordinals are wrong past 5 and for 0: "21th", "22th",
    // "11th" is right by accident, "0th" for exit 0.
    test('english roundabout ordinals are grammatical', () {
      String say(int e) => phraseFor(
        VoiceCue(
          step: step(ManeuverKind.roundabout, street: '', exit: e),
          stage: CueStage.now,
          distanceM: 30,
          stepIndex: 1,
        ),
        personaById('classic'),
        DistanceUnit.metric,
        'en',
      );
      expect(say(21), contains('21st'));
      expect(say(22), contains('22nd'));
      expect(say(23), contains('23rd'));
    });

    // BUG (P2): German "continueFor" uses the dative unit ("Metern") in a
    // sentence that needs the accusative: "300 Metern weiterfahren" (should
    // be "300 Meter weiterfahren"). The "In {dist}" form is correct.
    test('german prepare phrase uses the correct unit case', () {
      final s = phraseFor(
        VoiceCue(step: step(ManeuverKind.left), stage: CueStage.prepare, distanceM: 300, stepIndex: 1),
        personaById('classic'),
        DistanceUnit.metric,
        'de',
      );
      expect(s, startsWith('300 Meter weiterfahren'), reason: s);
    });

    // BUG (P2): decimal distances are spoken with a '.' in every language;
    // de/fr/es/it/tr TTS engines read "1.5 Kilometern" as "1. 5" / date /
    // "eins Punkt fünf" instead of "1,5".
    test('non-english decimal distances use a comma', () {
      for (final lang in ['de', 'fr', 'es', 'it', 'tr']) {
        final s = phraseFor(
          VoiceCue(step: step(ManeuverKind.left), stage: CueStage.approach, distanceM: 1500, stepIndex: 1),
          personaById('classic'),
          DistanceUnit.metric,
          lang,
        );
        expect(s, contains('1,5'), reason: '$lang: $s');
      }
    });

    test('reroute and sample phrases for every persona x language', () {
      for (final p in voicePersonas) {
        for (final lang in _langs) {
          expect(reroutePhrase(p, lang), isNotEmpty);
          expect(samplePhrase(p, lang), isNot(contains('{')));
        }
      }
      expect(personaById(null).id, 'classic');
      expect(personaById('nope').id, 'classic');
    });
  });

  group('performance', () {
    test('StyleBuilder.build / buildJson for all themes', () {
      final sw = Stopwatch()..start();
      var count = 0;
      for (var r = 0; r < 5; r++) {
        for (final t in themeCatalog) {
          for (final v in MapVariant.values) {
            builder.buildJson(t, v);
            count++;
          }
        }
      }
      sw.stop();
      final perMs = sw.elapsedMicroseconds / count / 1000;
      // ignore: avoid_print
      print('PERF StyleBuilder.buildJson: ${perMs.toStringAsFixed(2)} ms per theme/variant ($count builds)');
      expect(perMs, lessThan(16), reason: 'should fit in a frame');
    });

    test('MapPalette.inverted() (recomputed on every palette() call for the derived variant)', () {
      final sw = Stopwatch()..start();
      var count = 0;
      for (var r = 0; r < 50; r++) {
        for (final t in themeCatalog) {
          t.base.inverted();
          count++;
        }
      }
      sw.stop();
      // ignore: avoid_print
      print('PERF MapPalette.inverted: ${(sw.elapsedMicroseconds / count).toStringAsFixed(1)} µs per call');
      expect(sw.elapsedMicroseconds / count, lessThan(2000));
    });
  });
}
