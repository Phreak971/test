// QA: NavigationEngine stability, edge cases and performance.
//
// Tests marked `// BUG:` are expected to FAIL on the current code; they prove
// a defect and should pass once it is fixed.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:overworld/core/geo.dart';
import 'package:overworld/data/models.dart';
import 'package:overworld/nav/navigation_engine.dart';

import 'qa_support.dart';

const _origin = Geo(52.50, 13.40);

void _expectFinite(NavProgress p) {
  for (final v in [p.snapped.lat, p.snapped.lng, p.bearingDeg, p.distanceToNextM, p.remainingM, p.remainingS]) {
    expect(v.isFinite, isTrue, reason: 'non-finite value in progress: $v');
  }
}

void main() {
  group('long real route (Berlin -> Potsdam, OSRM polyline6)', () {
    final route = loadOsrm('qa_osrm_berlin_potsdam.json');

    test('fixture sanity', () {
      expect(route.geometry.length, greaterThan(500));
      expect(route.steps.length, greaterThan(10));
      expect(route.distanceM, greaterThan(30000));
      // Geometry length agrees with the reported distance within 1 %.
      final geomLen = cumulativeDistances(route.geometry).last;
      expect((geomLen - route.distanceM).abs() / route.distanceM, lessThan(0.01));
    });

    test('clean drive: monotone progress, no off-route, arrives, all values finite', () {
      final engine = NavigationEngine(route);
      NavProgress? last;
      var prevRemaining = double.infinity;
      for (final p in walkLine(route.geometry, 12)) {
        last = engine.update(Fix(p, speedMps: 14, accuracyM: 5));
        _expectFinite(last);
        expect(last.offRoute, isFalse);
        expect(last.remainingM, lessThanOrEqualTo(prevRemaining + 0.5));
        prevRemaining = last.remainingM;
      }
      expect(last!.arrived, isTrue);
    });

    test('noisy GPS (±12 m gaussian-ish, seeded) never triggers off-route and still arrives', () {
      final rnd = math.Random(42);
      double noise() => (rnd.nextDouble() + rnd.nextDouble() + rnd.nextDouble() - 1.5) * 16; // ~±12 m
      final engine = NavigationEngine(route);
      var offRoute = 0;
      NavProgress? last;
      for (final p in walkLine(route.geometry, 14)) {
        last = engine.update(Fix(offset(p, noise(), noise()), speedMps: 14, accuracyM: 12));
        _expectFinite(last);
        if (last.offRoute) offRoute++;
      }
      expect(offRoute, 0);
      expect(last!.arrived, isTrue);
    });

    test('stationary at a red light with jitter: progress does not creep and no off-route', () {
      final engine = NavigationEngine(route);
      final pts = walkLine(route.geometry, 10);
      for (final p in pts.take(200)) {
        engine.update(Fix(p, speedMps: 12));
      }
      final stopAt = pts[200];
      final base = engine.update(Fix(stopAt));
      final rnd = math.Random(7);
      NavProgress? p;
      for (var i = 0; i < 300; i++) {
        p = engine.update(Fix(offset(stopAt, (rnd.nextDouble() - 0.5) * 20, (rnd.nextDouble() - 0.5) * 20), accuracyM: 15));
        expect(p.offRoute, isFalse);
      }
      // Ratchet is bounded by the jitter amplitude (~10 m), not cumulative.
      expect(base.remainingM - p!.remainingM, lessThan(20));
    });

    test('GPS dropout jump forward 2 km re-acquires the route without going off-route', () {
      final engine = NavigationEngine(route);
      final pts = walkLine(route.geometry, 10);
      for (final p in pts.take(300)) {
        engine.update(Fix(p, speedMps: 14));
      }
      // Tunnel: no fixes for 2 km, then resume.
      NavProgress? p;
      for (final q in pts.skip(500).take(30)) {
        p = engine.update(Fix(q, speedMps: 14));
      }
      expect(p!.offRoute, isFalse);
      final truth = cumulativeDistances(route.geometry).last - 529 * 10;
      expect((p.remainingM - truth).abs(), lessThan(150));
    });
  });

  group('degenerate routes', () {
    test('same origin and destination (real OSRM response): arrives immediately, no crash', () {
      final route = loadOsrm('qa_osrm_same_point.json');
      expect(route.steps.length, 2);
      expect(route.distanceM, 0);
      final engine = NavigationEngine(route);
      final p = engine.update(Fix(route.geometry.first));
      expect(p.arrived, isTrue);
      _expectFinite(p);
      final cues = engine.cuesFor(p);
      expect(cues.single.stage, CueStage.arrive);
    });

    test('route with a single step (arrive only) does not crash', () {
      final g = [_origin, offset(_origin, 0, 100)];
      final route = RouteResult(
        geometry: g,
        distanceM: 100,
        durationS: 10,
        steps: [RouteStep(kind: ManeuverKind.arrive, location: g.last, distanceM: 100, durationS: 10, streetName: '', geometry: g)],
      );
      final engine = NavigationEngine(route);
      final p = engine.update(Fix(g.first));
      _expectFinite(p);
      expect(engine.cuesFor(p), isA<List<VoiceCue>>());
    });

    test('zero-length steps between maneuvers keep values finite', () {
      final route = syntheticRoute(_origin, [(0, 0), (0, 500), (0, 500), (300, 500)]);
      final engine = NavigationEngine(route);
      for (final p in walkLine(route.geometry, 10)) {
        _expectFinite(engine.update(Fix(p, speedMps: 10)));
      }
    });

    // BUG: parseOsrmRoute accepts a route without steps / with an empty
    // geometry and NavigationEngine then throws (RangeError / StateError) on
    // construction or first update. NavController.start() calls the
    // constructor synchronously from the "Start" button.
    test('route with empty geometry or no steps is rejected or handled without throwing', () {
      const empty = RouteResult(geometry: [], distanceM: 0, durationS: 0, steps: []);
      expect(() => NavigationEngine(empty).update(const Fix(_origin)), returnsNormally);
      final g = [_origin, offset(_origin, 0, 100)];
      final noSteps = RouteResult(geometry: g, distanceM: 100, durationS: 10, steps: const []);
      expect(() => NavigationEngine(noSteps).update(Fix(g.first)), returnsNormally);
    });

    test('NaN / Infinity fix values do not propagate into progress', () {
      final route = syntheticRoute(_origin, [(0, 0), (0, 1000), (500, 1000)]);
      final engine = NavigationEngine(route);
      engine.update(Fix(route.geometry.first, speedMps: 10));
      final p = engine.update(Fix(offset(_origin, 0, 100), headingDeg: double.nan, speedMps: double.nan, accuracyM: double.nan));
      _expectFinite(p);
    });

    // Regression: math.max(NaN, 8) is NaN, but num.clamp() maps NaN to the
    // upper bound, so cues still fire (at the widest thresholds). Lock it in.
    test('voice cues still fire when the fix speed is NaN', () {
      final route = syntheticRoute(_origin, [(0, 0), (0, 1000), (500, 1000)]);
      final engine = NavigationEngine(route);
      final stages = <CueStage>[];
      for (final p in walkLine(route.geometry, 10)) {
        final prog = engine.update(Fix(p));
        stages.addAll(engine.cuesFor(prog, speedMps: double.nan).map((c) => c.stage));
      }
      expect(stages, contains(CueStage.now));
    });
  });

  group('behavioural defects', () {
    // BUG: arrival is declared whenever the raw fix is within 30 m of the
    // destination, regardless of progress along the route. A loop route
    // ("drive around the block" / destination just behind you on a one-way
    // street) ends the moment navigation starts.
    test('loop route whose destination is near the start does not arrive at the start', () {
      // 600 m around a block, ending 20 m behind the start.
      final route = syntheticRoute(_origin, [(0, 0), (0, 200), (100, 200), (100, -20), (0, -20)]);
      final engine = NavigationEngine(route);
      final p = engine.update(Fix(route.geometry.first, speedMps: 0));
      expect(p.arrived, isFalse, reason: 'remaining ${p.remainingM.toStringAsFixed(0)} m of ${engine.totalM.toStringAsFixed(0)} m');
    });

    // BUG: same root cause — destination on the opposite carriageway. OSRM
    // routes past it, U-turns 1 km later and comes back; the engine
    // "arrives" when passing it on the wrong side of the road.
    test('passing the destination on the opposite carriageway does not count as arrival', () {
      // North 1000 m, U-turn across a 25 m median, back south 1000 m.
      // Destination is on the southbound side at 500 m (25 m from the
      // northbound lane).
      final route = syntheticRoute(_origin, [(0, 0), (0, 1000), (25, 1000), (25, 500)], kinds: [ManeuverKind.uturn, ManeuverKind.uturn]);
      final engine = NavigationEngine(route);
      NavProgress? p;
      for (final q in walkLine([_origin, offset(_origin, 0, 600)], 10)) {
        p = engine.update(Fix(q, speedMps: 13));
      }
      expect(p!.arrived, isFalse, reason: 'arrived after 600 m of a ${engine.totalM.round()} m route');
    });

    // BUG: a single multipath outlier near a LATER part of the route is
    // accepted by the global snap (it only requires being >60 m from the
    // window) and `_lastAlong` is a ratchet, so progress jumps forward
    // permanently. Real fixes afterwards are rejected as "backwards" and the
    // upcoming maneuvers are never announced.
    test('one GPS outlier near a later leg does not permanently skip progress', () {
      // U-shaped route: 2 km north, 150 m east, 2 km south.
      final route = syntheticRoute(_origin, [(0, 0), (0, 2000), (150, 2000), (150, 0)]);
      final engine = NavigationEngine(route);
      for (var y = 0.0; y <= 500; y += 10) {
        engine.update(Fix(offset(_origin, 0, y), speedMps: 13));
      }
      // One outlier 150 m east (lands exactly on the southbound leg).
      engine.update(Fix(offset(_origin, 150, 500), speedMps: 13, accuracyM: 30));
      NavProgress? p;
      for (var y = 510.0; y <= 700; y += 10) {
        p = engine.update(Fix(offset(_origin, 0, y), speedMps: 13));
      }
      final truthRemaining = engine.totalM - 700;
      expect(
        p!.remainingM,
        closeTo(truthRemaining, 100),
        reason: 'engine thinks ${p.remainingM.round()} m remain; truth ${truthRemaining.round()} m',
      );
      expect(p.currentStepIndex, 0);
    });

    // BUG: driving the route backwards (U-turn, wrong direction) is never
    // detected: the car stays on the polyline, so offRoute stays false, no
    // reroute happens and the banner freezes at the last forward distance.
    test('driving the route in the wrong direction eventually triggers off-route', () {
      final route = syntheticRoute(_origin, [(0, 0), (0, 3000), (500, 3000)]);
      final engine = NavigationEngine(route);
      for (var y = 0.0; y <= 1500; y += 10) {
        engine.update(Fix(offset(_origin, 0, y), headingDeg: 0, speedMps: 13));
      }
      var everOff = false;
      for (var y = 1500.0; y >= 900; y -= 10) {
        final p = engine.update(Fix(offset(_origin, 0, y), headingDeg: 180, speedMps: 13));
        everOff |= p.offRoute;
      }
      expect(everOff, isTrue, reason: 'drove 600 m backwards along the route without any off-route/reroute');
    });
  });

  group('geo robustness used by the engine', () {
    // BUG: snapToLine projects in raw longitude, so a segment crossing the
    // antimeridian (roads on Taveuni/Fiji, Chukotka) is treated as spanning
    // the whole globe; only the endpoints can match, so a point ON the road
    // at 180° is reported ~1 km away (=> off-route with the 40 m threshold).
    test('snapToLine handles a segment crossing the antimeridian', () {
      const line = [Geo(-16.80, 179.99), Geo(-16.80, -179.99)];
      final s = snapToLine(const Geo(-16.80, 180.0), line);
      expect(s.distanceFromLineM, lessThan(5));
    });

    test('snapToLine near the pole stays finite', () {
      const line = [Geo(89.99, 0), Geo(89.99, 90)];
      final s = snapToLine(const Geo(89.99, 45), line);
      expect(s.distanceFromLineM.isFinite, isTrue);
      expect(s.alongM.isFinite, isTrue);
    });
  });

  group('performance', () {
    test('update() per fix on a long route (Berlin -> Munich) is well under 5 ms', () {
      final route = loadOsrm('qa_osrm_berlin_munich.json');
      final engine = NavigationEngine(route);
      final pts = walkLine(route.geometry, 25);
      final sw = Stopwatch()..start();
      for (final p in pts) {
        engine.update(Fix(p, speedMps: 30));
      }
      sw.stop();
      final perFixUs = sw.elapsedMicroseconds / pts.length;
      // ignore: avoid_print
      print('PERF on-route update: ${route.geometry.length} vertices, ${pts.length} fixes, ${perFixUs.toStringAsFixed(1)} µs/fix');
      expect(perFixUs, lessThan(5000));
    });

    test('update() while off-route (global O(n) snap every fix) on a long route', () {
      final route = loadOsrm('qa_osrm_berlin_munich.json');
      final engine = NavigationEngine(route);
      final pts = walkLine(route.geometry, 25);
      for (final p in pts.take(2000)) {
        engine.update(Fix(p, speedMps: 30));
      }
      // Detour 500 m off the route for 200 fixes.
      final base = pts[2000];
      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        engine.update(Fix(offset(base, 500, i.toDouble()), speedMps: 10));
      }
      sw.stop();
      final perFixUs = sw.elapsedMicroseconds / 200;
      // ignore: avoid_print
      print('PERF off-route update (global snap): ${route.geometry.length} vertices, ${perFixUs.toStringAsFixed(1)} µs/fix');
      expect(perFixUs, lessThan(5000));
    });

    test('engine construction on a long route', () {
      final route = loadOsrm('qa_osrm_berlin_munich.json');
      final sw = Stopwatch()..start();
      for (var i = 0; i < 10; i++) {
        NavigationEngine(route);
      }
      sw.stop();
      // ignore: avoid_print
      print('PERF NavigationEngine(): ${(sw.elapsedMicroseconds / 10 / 1000).toStringAsFixed(2)} ms for ${route.geometry.length} vertices');
      expect(sw.elapsedMilliseconds / 10, lessThan(100));
    });
  });
}
