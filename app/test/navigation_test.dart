import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/core/units.dart';
import 'package:overworld/data/models.dart';
import 'package:overworld/data/routing_service.dart';
import 'package:overworld/nav/navigation_engine.dart';
import 'package:overworld/nav/voice.dart';

RouteResult berlinRoute() =>
    parseOsrmRoute(jsonDecode(File('test/fixtures/osrm_berlin.json').readAsStringSync()) as Map<String, dynamic>);

/// Points every [stepM] metres along [line].
List<Geo> walk(List<Geo> line, double stepM) {
  final out = <Geo>[line.first];
  var carry = 0.0;
  for (var i = 0; i < line.length - 1; i++) {
    final a = line[i], b = line[i + 1];
    final seg = distanceM(a, b);
    var d = stepM - carry;
    while (d < seg) {
      final t = d / seg;
      out.add(Geo(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t));
      d += stepM;
    }
    carry = seg - (d - stepM);
  }
  out.add(line.last);
  return out;
}

void main() {
  test('drives the whole route and arrives', () {
    final route = berlinRoute();
    final engine = NavigationEngine(route);
    NavProgress? last;
    var maxStep = 0;
    var prevRemaining = double.infinity;
    for (final p in walk(route.geometry, 15)) {
      last = engine.update(Fix(p, speedMps: 12, accuracyM: 5));
      expect(last.offRoute, isFalse, reason: 'should not be off-route on the route itself');
      // Remaining distance is monotonically non-increasing.
      expect(last.remainingM, lessThanOrEqualTo(prevRemaining + 0.5));
      prevRemaining = last.remainingM;
      expect(last.currentStepIndex, greaterThanOrEqualTo(maxStep));
      maxStep = last.currentStepIndex;
    }
    expect(last!.arrived, isTrue);
    expect(last.remainingM, 0);
    expect(maxStep, greaterThanOrEqualTo(route.steps.length - 2));
  });

  test('remaining time decreases from the full estimate', () {
    final route = berlinRoute();
    final engine = NavigationEngine(route);
    final first = engine.update(Fix(route.geometry.first, speedMps: 10));
    expect(first.remainingS, closeTo(route.durationS, route.durationS * 0.05));
    final pts = walk(route.geometry, 50);
    final mid = engine.update(Fix(pts[pts.length ~/ 2], speedMps: 10));
    expect(mid.remainingS, lessThan(first.remainingS));
    expect(mid.remainingS, greaterThan(0));
  });

  test('detects off-route after 3 consecutive bad fixes', () {
    final route = berlinRoute();
    final engine = NavigationEngine(route);
    engine.update(Fix(route.geometry.first));
    final far = Geo(route.geometry.first.lat + 0.01, route.geometry.first.lng);
    expect(engine.update(Fix(far)).offRoute, isFalse);
    expect(engine.update(Fix(far)).offRoute, isFalse);
    expect(engine.update(Fix(far)).offRoute, isTrue);
    // Back on route resets.
    expect(engine.update(Fix(route.geometry[2])).offRoute, isFalse);
  });

  test('GPS jitter backwards does not rewind progress', () {
    final route = berlinRoute();
    final engine = NavigationEngine(route);
    final pts = walk(route.geometry, 20);
    final a = engine.update(Fix(pts[30]));
    final b = engine.update(Fix(pts[29]));
    expect(b.remainingM, lessThanOrEqualTo(a.remainingM + 0.1));
  });

  test('voice cues fire once per stage and in order', () {
    final route = berlinRoute();
    final engine = NavigationEngine(route);
    final stages = <String>[];
    for (final p in walk(route.geometry, 10)) {
      final prog = engine.update(Fix(p, speedMps: 13));
      for (final c in engine.cuesFor(prog, speedMps: 13)) {
        stages.add('${c.stepIndex}:${c.stage.name}');
      }
    }
    expect(stages.toSet().length, stages.length, reason: 'no duplicate cues');
    expect(stages.last, endsWith('arrive'));
    // For each maneuver, "now" never precedes "approach".
    final byStep = <int, List<String>>{};
    for (final s in stages.where((s) => !s.endsWith('arrive'))) {
      final i = int.parse(s.split(':').first);
      byStep.putIfAbsent(i, () => []).add(s.split(':').last);
    }
    for (final e in byStep.entries) {
      final idxNow = e.value.indexOf('now');
      final idxApproach = e.value.indexOf('approach');
      if (idxNow >= 0 && idxApproach >= 0) expect(idxApproach, lessThan(idxNow));
    }
  });

  group('phrases', () {
    const step = RouteStep(
      kind: ManeuverKind.left,
      location: Geo(0, 0),
      distanceM: 100,
      durationS: 10,
      streetName: 'Main Street',
      geometry: [Geo(0, 0), Geo(0, 0.001)],
    );

    test('classic english includes street', () {
      final s = phraseFor(const VoiceCue(step: step, stage: CueStage.approach, distanceM: 300, stepIndex: 1), personaById('classic'), DistanceUnit.metric, 'en');
      expect(s, 'In 300 meters, turn left onto Main Street');
    });

    test('german', () {
      final s = phraseFor(const VoiceCue(step: step, stage: CueStage.now, distanceM: 50, stepIndex: 1), personaById('classic'), DistanceUnit.metric, 'de');
      expect(s, 'Jetzt links abbiegen auf Main Street');
    });

    test('persona flavour stays in english only', () {
      final en = phraseFor(const VoiceCue(step: step, stage: CueStage.approach, distanceM: 300, stepIndex: 1), personaById('ranger'), DistanceUnit.metric, 'en');
      expect(en.toLowerCase(), contains('turn left'));
      final fr = phraseFor(const VoiceCue(step: step, stage: CueStage.approach, distanceM: 300, stepIndex: 1), personaById('ranger'), DistanceUnit.metric, 'fr');
      expect(fr, startsWith('Dans 300 mètres'));
    });

    test('roundabout exit', () {
      const r = RouteStep(kind: ManeuverKind.roundabout, location: Geo(0, 0), distanceM: 1, durationS: 1, streetName: '', geometry: [Geo(0, 0), Geo(0, 1)], roundaboutExit: 2);
      final s = phraseFor(const VoiceCue(step: r, stage: CueStage.now, distanceM: 30, stepIndex: 1), personaById('classic'), DistanceUnit.imperial, 'en');
      expect(s, 'At the roundabout, take the second exit');
    });

    test('every persona and language yields text', () {
      for (final p in voicePersonas) {
        for (final lang in ['en', 'de', 'fr', 'it', 'es', 'tr', 'xx']) {
          for (final stage in CueStage.values) {
            final s = phraseFor(VoiceCue(step: step, stage: stage, distanceM: 420, stepIndex: 2), p, DistanceUnit.metric, lang);
            expect(s.trim(), isNotEmpty);
            expect(s, isNot(contains('{')));
          }
          expect(samplePhrase(p, lang), isNotEmpty);
          expect(reroutePhrase(p, lang), isNotEmpty);
        }
      }
    });
  });
}
