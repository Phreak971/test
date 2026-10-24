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
    : _degenerate = route.geometry.length < 2 || route.steps.isEmpty,
      _cum = route.geometry.length < 2 ? const [0.0] : cumulativeDistances(route.geometry),
      _stepStart = route.geometry.length < 2 || route.steps.isEmpty ? const [0.0] : _computeStepStarts(route);

  final RouteResult route;

  /// Nothing to navigate (OSRM edge cases); every update reports arrival.
  final bool _degenerate;
  final List<double> _cum;
  final List<double> _stepStart;

  int _lastSegment = 0;
  double _lastAlong = 0;
  int _offRouteStreak = 0;
  int _wrongWayStreak = 0;
  bool _arrived = false;
  DateTime? _lastFixAt;

  /// Forward jump candidate awaiting confirmation by consecutive fixes.
  double? _pendingJumpAlong;
  int _pendingJumpCount = 0;
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

  static double _finite(double v, double fallback) => v.isFinite ? v : fallback;

  NavProgress update(Fix fix) {
    if (_degenerate) {
      _arrived = true;
      return NavProgress(
        snapped: fix.position,
        bearingDeg: 0,
        currentStepIndex: 0,
        nextStep: null,
        distanceToNextM: 0,
        remainingM: 0,
        remainingS: 0,
        offRoute: false,
        arrived: true,
      );
    }
    final accuracy = _finite(fix.accuracyM, 30).clamp(3.0, 100.0);
    final speed = _finite(fix.speedMps, 0).clamp(0.0, 70.0);
    final heading = fix.headingDeg != null && fix.headingDeg!.isFinite ? fix.headingDeg : null;
    final at = fix.at;
    final dt = at != null && _lastFixAt != null ? (at.difference(_lastFixAt!).inMilliseconds / 1000).clamp(0.5, 30.0) : 2.0;
    if (at != null) _lastFixAt = at;

    final threshold = math.max(40.0, accuracy * 1.5);
    final backTol = 50 + accuracy;
    final maxForward = math.max(speed, 15.0) * dt + 2 * accuracy + 50;

    // 1) Match only within plausible progress around where we were.
    final local = _constrainedSnap(fix.position, _lastAlong - backTol, _lastAlong + maxForward);
    Snap? accepted;
    var backwards = false;
    if (local != null && local.distanceFromLineM <= threshold) {
      accepted = local;
      _pendingJumpAlong = null;
      _pendingJumpCount = 0;
    } else {
      // 2) Lost the window: look along the whole route.
      final global = snapToLine(fix.position, route.geometry, cumulative: _cum);
      if (global.distanceFromLineM <= threshold) {
        if (global.alongM < _lastAlong - backTol) {
          backwards = true; // driving back along the route
        } else {
          // Forward jump (tunnel exit, outlier): accept after 3 agreeing fixes.
          final pending = _pendingJumpAlong;
          if (pending != null && (global.alongM - pending).abs() <= maxForward) {
            _pendingJumpCount++;
          } else {
            _pendingJumpCount = 1;
          }
          _pendingJumpAlong = global.alongM;
          if (_pendingJumpCount >= 3) {
            accepted = global;
            _pendingJumpAlong = null;
            _pendingJumpCount = 0;
          }
        }
      }
    }

    if (accepted != null) {
      _offRouteStreak = 0;
      if (accepted.alongM >= _lastAlong) {
        _lastAlong = accepted.alongM;
        _lastSegment = accepted.segmentIndex;
      }
    } else if (!backwards && _pendingJumpAlong == null) {
      _offRouteStreak++;
    }

    // Wrong way: moving against the route direction, or matching behind us.
    final seg = _lastSegment.clamp(0, route.geometry.length - 2);
    final segBearing = bearingDeg(route.geometry[seg], route.geometry[seg + 1]);
    final opposing = heading != null && speed > 3 && angleDelta(segBearing, heading).abs() > 135;
    if (backwards || opposing) {
      _wrongWayStreak++;
    } else if (accepted != null) {
      _wrongWayStreak = 0;
    }

    final along = _lastAlong;
    final remainingM = math.max(0.0, totalM - along);
    final destDist = distanceM(fix.position, route.geometry.last);
    // Arrive only when progress along the route agrees with proximity, so a
    // loop route or a destination across a median doesn't end early.
    if (!_arrived && (remainingM <= 15 || (destDist <= arrivalRadiusM && remainingM <= math.max(80.0, 2 * accuracy)))) {
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

    final onLine = accepted != null;
    return NavProgress(
      snapped: onLine ? accepted.point : fix.position,
      bearingDeg: !onLine && heading != null && speed > 3 ? heading : segBearing,
      currentStepIndex: stepIdx,
      nextStep: next,
      followingStep: next != null && distToNext < 250 ? following : null,
      distanceToNextM: distToNext,
      remainingM: _arrived ? 0 : remainingM,
      remainingS: remainingS,
      offRoute: !_arrived && (_offRouteStreak >= 3 || _wrongWayStreak >= 3),
      arrived: _arrived,
    );
  }

  /// Nearest point on the route restricted to progress in [minAlong, maxAlong].
  Snap? _constrainedSnap(Geo p, double minAlong, double maxAlong) {
    // Segments overlapping the allowed range.
    var from = _lastSegment;
    while (from > 0 && _cum[from] > minAlong) {
      from--;
    }
    var to = _lastSegment;
    while (to < route.geometry.length - 2 && _cum[to + 1] < maxAlong) {
      to++;
    }
    final sub = route.geometry.sublist(from, to + 2);
    final s = snapToLine(p, sub, cumulative: [for (var i = from; i <= to + 1; i++) _cum[i] - _cum[from]]);
    final along = _cum[from] + s.alongM;
    if (along < minAlong - 1 || along > maxAlong + 1) {
      // Closest point is outside the window; clamp to the window edge.
      final edge = along < minAlong ? minAlong : maxAlong;
      final i = _segmentAt(edge);
      final segLen = _cum[i + 1] - _cum[i];
      final t = segLen <= 0 ? 0.0 : ((edge - _cum[i]) / segLen).clamp(0.0, 1.0);
      final a = route.geometry[i], b = route.geometry[i + 1];
      final pt = Geo(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
      return Snap(point: pt, segmentIndex: i, fraction: t, distanceFromLineM: distanceM(p, pt), alongM: edge);
    }
    return Snap(
      point: s.point,
      segmentIndex: s.segmentIndex + from,
      fraction: s.fraction,
      distanceFromLineM: s.distanceFromLineM,
      alongM: along,
    );
  }

  int _segmentAt(double along) {
    var lo = 0, hi = route.geometry.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_cum[mid] <= along) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Voice cues due for [p] at [speedMps]; each cue fires once.
  List<VoiceCue> cuesFor(NavProgress p, {double speedMps = 0}) {
    final out = <VoiceCue>[];
    if (route.steps.isEmpty) return out;
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
