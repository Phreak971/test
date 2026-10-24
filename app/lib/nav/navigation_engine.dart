import 'dart:math' as math;

import '../core/geo.dart';
import '../data/models.dart';

/// One GPS fix.
class Fix {
  const Fix(this.position, {this.headingDeg, this.speedMps = 0, this.accuracyM = 10, this.at});

  final Geo position;
  final double? headingDeg;
  final double speedMps;
  final double accuracyM;
  final DateTime? at;
}

enum CueStage {
  /// Right after the previous maneuver: "Continue for 2 km, then turn left".
  prepare,

  /// ~ 20-30 s before the maneuver.
  approach,

  /// Imminent: "Turn left now".
  now,

  arrive,
}

class VoiceCue {
  const VoiceCue({required this.step, required this.stage, required this.distanceM, required this.stepIndex});

  final RouteStep step;
  final CueStage stage;
  final double distanceM;
  final int stepIndex;
}

class NavProgress {
  const NavProgress({
    required this.snapped,
    required this.bearingDeg,
    required this.currentStepIndex,
    required this.nextStep,
    required this.distanceToNextM,
    required this.remainingM,
    required this.remainingS,
    required this.offRoute,
    required this.arrived,
    this.followingStep,
  });

  final Geo snapped;
  final double bearingDeg;
  final int currentStepIndex;

  /// The upcoming maneuver (null only after arrival).
  final RouteStep? nextStep;

  /// The maneuver after [nextStep], shown as "Then ..." when close.
  final RouteStep? followingStep;
  final double distanceToNextM;
  final double remainingM;
  final double remainingS;
  final bool offRoute;
  final bool arrived;
}

/// Tracks progress along a [RouteResult] from a stream of fixes.
///
/// Pure Dart and deterministic so it can be unit tested and shared by the
/// phone UI and the car screens.
class NavigationEngine {
  NavigationEngine(this.route)
      : _cum = cumulativeDistances(route.geometry),
        _stepStart = _computeStepStarts(route);

  final RouteResult route;
  final List<double> _cum;
  final List<double> _stepStart;

  int _lastSegment = 0;
  double _lastAlong = 0;
  int _offRouteStreak = 0;
  bool _arrived = false;
  final _spokenCues = <String>{};

  static const arrivalRadiusM = 30.0;

  static List<double> _computeStepStarts(RouteResult r) {
    final out = <double>[];
    var acc = 0.0;
    for (final s in r.steps) {
      out.add(acc);
      acc += s.distanceM;
    }
    // Scale to the geometry length so step offsets line up with snapping.
    final geomLen = cumulativeDistances(r.geometry).last;
    if (acc > 0 && geomLen > 0) {
      final k = geomLen / acc;
      for (var i = 0; i < out.length; i++) {
        out[i] *= k;
      }
    }
    return out;
  }

  double get totalM => _cum.last;
  bool get arrived => _arrived;

  NavProgress update(Fix fix) {
    final window = _windowedSnap(fix.position);
    final threshold = math.max(40.0, fix.accuracyM * 1.5);
    if (window.distanceFromLineM > threshold) {
      _offRouteStreak++;
    } else {
      _offRouteStreak = 0;
      if (window.alongM >= _lastAlong - 25) {
        _lastAlong = math.max(_lastAlong, window.alongM);
        _lastSegment = window.segmentIndex;
      }
    }
    final along = _lastAlong;
    final remainingM = math.max(0.0, totalM - along);
    final destDist = distanceM(fix.position, route.geometry.last);
    if (!_arrived && (destDist <= arrivalRadiusM || remainingM <= 15)) {
      _arrived = true;
    }

    var stepIdx = 0;
    for (var i = 0; i < _stepStart.length; i++) {
      if (_stepStart[i] <= along + 1) stepIdx = i;
    }
    final nextIdx = math.min(stepIdx + 1, route.steps.length - 1);
    final next = _arrived ? null : route.steps[nextIdx];
    final following = nextIdx + 1 < route.steps.length ? route.steps[nextIdx + 1] : null;
    final distToNext = _arrived ? 0.0 : math.max(0.0, _stepStart[nextIdx] - along);

    // Remaining time: proportional to remaining distance of the current step
    // plus durations of all later steps.
    var remainingS = 0.0;
    if (!_arrived) {
      final cur = route.steps[stepIdx];
      final stepLen = (nextIdx > stepIdx ? _stepStart[nextIdx] : totalM) - _stepStart[stepIdx];
      final fracLeft = stepLen <= 0 ? 0.0 : (distToNext / stepLen).clamp(0.0, 1.0);
      remainingS = cur.durationS * fracLeft;
      for (var i = stepIdx + 1; i < route.steps.length; i++) {
        remainingS += route.steps[i].durationS;
      }
    }

    final seg = _lastSegment.clamp(0, route.geometry.length - 2);
    final bearing = bearingDeg(route.geometry[seg], route.geometry[seg + 1]);

    return NavProgress(
      snapped: _offRouteStreak > 0 ? fix.position : window.point,
      bearingDeg: fix.headingDeg != null && fix.speedMps > 3 && _offRouteStreak > 0 ? fix.headingDeg! : bearing,
      currentStepIndex: stepIdx,
      nextStep: next,
      followingStep: next != null && distToNext < 250 ? following : null,
      distanceToNextM: distToNext,
      remainingM: _arrived ? 0 : remainingM,
      remainingS: remainingS,
      offRoute: !_arrived && _offRouteStreak >= 3,
      arrived: _arrived,
    );
  }

  Snap _windowedSnap(Geo p) {
    final n = route.geometry.length;
    final from = math.max(0, math.min(_lastSegment - 3, n - 2));
    final to = math.min(n, math.max(from + 2, _lastSegment + 60));
    final s = snapToLine(p, route.geometry.sublist(from, to));
    // If the window lost track (e.g. GPS jump), fall back to a global snap.
    if (s.distanceFromLineM > 60) {
      final global = snapToLine(p, route.geometry, cumulative: _cum);
      if (global.distanceFromLineM + 5 < s.distanceFromLineM) return global;
    }
    return Snap(
      point: s.point,
      segmentIndex: s.segmentIndex + from,
      fraction: s.fraction,
      distanceFromLineM: s.distanceFromLineM,
      alongM: _cum[s.segmentIndex + from] + (_cum[s.segmentIndex + from + 1] - _cum[s.segmentIndex + from]) * s.fraction,
    );
  }

  /// Voice cues due for [p] at [speedMps]; each cue fires once.
  List<VoiceCue> cuesFor(NavProgress p, {double speedMps = 0}) {
    final out = <VoiceCue>[];
    if (p.arrived) {
      if (_spokenCues.add('arrive')) {
        out.add(VoiceCue(step: route.steps.last, stage: CueStage.arrive, distanceM: 0, stepIndex: route.steps.length - 1));
      }
      return out;
    }
    final next = p.nextStep;
    if (next == null) return out;
    final idx = p.currentStepIndex + 1;
    final v = math.max(speedMps, 8.0);
    final approachAt = (v * 25).clamp(200.0, 1500.0);
    final nowAt = (v * 6).clamp(40.0, 150.0);
    void fire(CueStage stage) {
      if (_spokenCues.add('$idx:${stage.name}')) {
        out.add(VoiceCue(step: next, stage: stage, distanceM: p.distanceToNextM, stepIndex: idx));
      }
    }

    if (p.distanceToNextM <= nowAt) {
      fire(CueStage.now);
      _spokenCues.add('$idx:${CueStage.approach.name}');
      _spokenCues.add('$idx:${CueStage.prepare.name}');
    } else if (p.distanceToNextM <= approachAt) {
      fire(CueStage.approach);
      _spokenCues.add('$idx:${CueStage.prepare.name}');
    } else if (p.distanceToNextM > approachAt + 200) {
      fire(CueStage.prepare);
    }
    return out;
  }
}
