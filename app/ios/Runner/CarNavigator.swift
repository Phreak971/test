import CoreLocation
import Foundation

enum CarCueStage: String {
  /// Right after the previous maneuver: "Continue for 2 km, then turn left".
  case prepare
  /// ~25 s before the maneuver.
  case approach
  /// Imminent: "Turn left now".
  case now
  case arrive
}

struct CarCue {
  let step: CarStep
  let stage: CarCueStage
  let distanceM: Double
  let stepIndex: Int
}

struct CarProgress {
  var snapped: CLLocationCoordinate2D
  var bearingDeg: Double
  var currentStepIndex: Int
  /// Index of the upcoming maneuver (nil after arrival).
  var nextStepIndex: Int?
  /// Maneuver after the next one, only when the next one is close.
  var followingStepIndex: Int?
  var distanceToNextM: Double
  var remainingM: Double
  var remainingS: Double
  var offRoute: Bool
  var arrived: Bool
}

/// Progress along a route from GPS fixes: a simplified Swift port of
/// lib/nav/navigation_engine.dart (windowed snapping, step by cumulative
/// distance, off-route after 3 fixes > 40 m, arrival within 30 m).
final class CarNavigator {
  static let arrivalRadiusM = 30.0

  let route: CarRoute
  private let cum: [Double]
  private let stepStart: [Double]

  private var lastSegment = 0
  private var lastAlong = 0.0
  private var offRouteStreak = 0
  private(set) var arrived = false
  private var spoken = Set<String>()

  /// `route` must have >= 2 geometry points and >= 1 step (CarServices
  /// guarantees this).
  init(route: CarRoute) {
    self.route = route
    cum = CarGeo.cumulativeDistances(route.geometry)
    var starts: [Double] = []
    var acc = 0.0
    for s in route.steps {
      starts.append(acc)
      acc += s.distanceM
    }
    // Scale to the geometry length so step offsets line up with snapping.
    let geomLen = cum.last ?? 0
    if acc > 0 && geomLen > 0 {
      let k = geomLen / acc
      starts = starts.map { $0 * k }
    }
    stepStart = starts
  }

  var totalM: Double { cum.last ?? 0 }

  func update(_ fix: CLLocation) -> CarProgress {
    let p = fix.coordinate
    let geom = route.geometry
    let snap = windowedSnap(p)
    let accuracy = fix.horizontalAccuracy >= 0 ? fix.horizontalAccuracy : 10
    let threshold = max(40, accuracy * 1.5)
    if snap.snap.distanceFromLineM > threshold {
      offRouteStreak += 1
    } else {
      offRouteStreak = 0
      if snap.along >= lastAlong - 25 {
        lastAlong = max(lastAlong, snap.along)
        lastSegment = snap.snap.segmentIndex
      }
    }
    let along = lastAlong
    let remainingM = max(0, totalM - along)
    let destDist = CarGeo.distance(p, geom[geom.count - 1])
    if !arrived && (destDist <= Self.arrivalRadiusM || remainingM <= 15) {
      arrived = true
    }

    let steps = route.steps
    var stepIdx = 0
    for i in 0..<stepStart.count where stepStart[i] <= along + 1 {
      stepIdx = i
    }
    let nextIdx = min(stepIdx + 1, steps.count - 1)
    let distToNext = arrived ? 0 : max(0, stepStart[nextIdx] - along)
    let followingIdx: Int? = (!arrived && nextIdx + 1 < steps.count && distToNext < 250) ? nextIdx + 1 : nil

    // Remaining time: the unfinished share of the current step + later steps.
    var remainingS = 0.0
    if !arrived {
      let stepLen = (nextIdx > stepIdx ? stepStart[nextIdx] : totalM) - stepStart[stepIdx]
      let fracLeft = stepLen <= 0 ? 0 : min(1, max(0, distToNext / stepLen))
      remainingS = steps[stepIdx].durationS * fracLeft
      if stepIdx + 1 < steps.count {
        for i in (stepIdx + 1)..<steps.count { remainingS += steps[i].durationS }
      }
    }

    let seg = min(max(0, lastSegment), geom.count - 2)
    let lineBearing = CarGeo.bearing(geom[seg], geom[seg + 1])
    let useCourse = fix.course >= 0 && fix.speed > 3 && offRouteStreak > 0

    return CarProgress(
      snapped: offRouteStreak > 0 ? p : snap.snap.point,
      bearingDeg: useCourse ? fix.course : lineBearing,
      currentStepIndex: stepIdx,
      nextStepIndex: arrived ? nil : nextIdx,
      followingStepIndex: followingIdx,
      distanceToNextM: distToNext,
      remainingM: arrived ? 0 : remainingM,
      remainingS: remainingS,
      offRoute: !arrived && offRouteStreak >= 3,
      arrived: arrived)
  }

  private func windowedSnap(_ p: CLLocationCoordinate2D) -> (snap: CarGeo.Snap, along: Double) {
    let geom = route.geometry
    let n = geom.count
    let from = max(0, min(lastSegment - 3, n - 2))
    let to = min(n, max(from + 2, lastSegment + 60))
    var s = CarGeo.snap(p, to: geom, from: from, end: to)
    // If the window lost track (e.g. GPS jump), fall back to a global snap.
    if s.distanceFromLineM > 60 {
      let global = CarGeo.snap(p, to: geom)
      if global.distanceFromLineM + 5 < s.distanceFromLineM { s = global }
    }
    let i = min(max(0, s.segmentIndex), n - 2)
    return (s, cum[i] + (cum[i + 1] - cum[i]) * s.fraction)
  }

  /// Voice cues due for `p` at `speedMps`; each cue fires once.
  func cues(for p: CarProgress, speedMps: Double) -> [CarCue] {
    var out: [CarCue] = []
    if p.arrived {
      if spoken.insert("arrive").inserted, let last = route.steps.last {
        out.append(CarCue(step: last, stage: .arrive, distanceM: 0, stepIndex: route.steps.count - 1))
      }
      return out
    }
    guard let idx = p.nextStepIndex, idx < route.steps.count else { return out }
    let next = route.steps[idx]
    let v = max(speedMps, 8)
    let approachAt = min(1500, max(200, v * 25))
    let nowAt = min(150, max(40, v * 6))

    func fire(_ stage: CarCueStage) {
      if spoken.insert("\(idx):\(stage.rawValue)").inserted {
        out.append(CarCue(step: next, stage: stage, distanceM: p.distanceToNextM, stepIndex: idx))
      }
    }

    if p.distanceToNextM <= nowAt {
      fire(.now)
      spoken.insert("\(idx):\(CarCueStage.approach.rawValue)")
      spoken.insert("\(idx):\(CarCueStage.prepare.rawValue)")
    } else if p.distanceToNextM <= approachAt {
      fire(.approach)
      spoken.insert("\(idx):\(CarCueStage.prepare.rawValue)")
    } else if p.distanceToNextM > approachAt + 200 {
      fire(.prepare)
    }
    return out
  }
}
