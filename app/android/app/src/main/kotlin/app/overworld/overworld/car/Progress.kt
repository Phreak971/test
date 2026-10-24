package app.overworld.overworld.car

import kotlin.math.max
import kotlin.math.min

/** One location fix. */
data class Fix(
    val position: GeoPoint,
    val headingDeg: Double? = null,
    val speedMps: Double = 0.0,
    val accuracyM: Double = 10.0,
)

enum class CueStage { PREPARE, APPROACH, NOW, ARRIVE }

data class VoiceCue(val step: RouteStep, val stage: CueStage, val distanceM: Double, val stepIndex: Int)

data class NavProgress(
    val snapped: GeoPoint,
    val bearingDeg: Double,
    val currentStepIndex: Int,
    /** The upcoming maneuver (null only after arrival). */
    val nextStep: RouteStep?,
    val nextStepIndex: Int,
    /** The maneuver after [nextStep], when close. */
    val followingStep: RouteStep?,
    val distanceToNextM: Double,
    val remainingM: Double,
    val remainingS: Double,
    val offRoute: Boolean,
    val arrived: Boolean,
)

/**
 * Tracks progress along a [Route] from a stream of fixes. A Kotlin port of
 * `NavigationEngine` in lib/nav/navigation_engine.dart: windowed snapping,
 * step by cumulative distance, off-route after 3 fixes > 40 m, arrival
 * within 30 m.
 */
class ProgressTracker(val route: Route) {
    private val cum: DoubleArray = Geo.cumulativeDistances(route.geometry)
    private val stepStart: DoubleArray = computeStepStarts(route, cum.last())

    private var lastSegment = 0
    private var lastAlong = 0.0
    private var offRouteStreak = 0
    var arrived = false
        private set
    private val spokenCues = HashSet<String>()

    val totalM: Double get() = cum.last()

    companion object {
        const val ARRIVAL_RADIUS_M = 30.0
        const val OFF_ROUTE_M = 40.0
        const val OFF_ROUTE_FIXES = 3

        private fun computeStepStarts(r: Route, geomLen: Double): DoubleArray {
            val out = DoubleArray(r.steps.size)
            var acc = 0.0
            for (i in r.steps.indices) {
                out[i] = acc
                acc += r.steps[i].distanceM
            }
            // Scale to the geometry length so step offsets line up with snapping.
            if (acc > 0 && geomLen > 0) {
                val k = geomLen / acc
                for (i in out.indices) out[i] *= k
            }
            return out
        }
    }

    fun update(fix: Fix): NavProgress {
        val geometry = route.geometry
        val window = windowedSnap(fix.position)
        val threshold = max(OFF_ROUTE_M, fix.accuracyM * 1.5)
        if (window.distanceFromLineM > threshold) {
            offRouteStreak++
        } else {
            offRouteStreak = 0
            if (window.alongM >= lastAlong - 25) {
                lastAlong = max(lastAlong, window.alongM)
                lastSegment = window.segmentIndex
            }
        }
        val along = lastAlong
        val remainingM = max(0.0, totalM - along)
        val destDist = Geo.distanceM(fix.position, geometry.last())
        if (!arrived && (destDist <= ARRIVAL_RADIUS_M || remainingM <= 15)) arrived = true

        val steps = route.steps
        var stepIdx = 0
        for (i in stepStart.indices) if (stepStart[i] <= along + 1) stepIdx = i
        val nextIdx = if (steps.isEmpty()) 0 else min(stepIdx + 1, steps.size - 1)
        val next = if (arrived || steps.isEmpty()) null else steps[nextIdx]
        val following = if (nextIdx + 1 < steps.size) steps[nextIdx + 1] else null
        val distToNext = if (arrived || steps.isEmpty()) 0.0 else max(0.0, stepStart[nextIdx] - along)

        var remainingS = 0.0
        if (!arrived && steps.isNotEmpty()) {
            val cur = steps[stepIdx]
            val stepLen = (if (nextIdx > stepIdx) stepStart[nextIdx] else totalM) - stepStart[stepIdx]
            val fracLeft = if (stepLen <= 0) 0.0 else (distToNext / stepLen).coerceIn(0.0, 1.0)
            remainingS = cur.durationS * fracLeft
            for (i in stepIdx + 1 until steps.size) remainingS += steps[i].durationS
        }

        val seg = lastSegment.coerceIn(0, max(0, geometry.size - 2))
        val bearing = if (geometry.size >= 2) Geo.bearingDeg(geometry[seg], geometry[seg + 1]) else (fix.headingDeg ?: 0.0)
        val useHeading = fix.headingDeg != null && fix.speedMps > 3 && offRouteStreak > 0

        return NavProgress(
            snapped = if (offRouteStreak > 0) fix.position else window.point,
            bearingDeg = if (useHeading) fix.headingDeg else bearing,
            currentStepIndex = stepIdx,
            nextStep = next,
            nextStepIndex = nextIdx,
            followingStep = if (next != null && distToNext < 250) following else null,
            distanceToNextM = distToNext,
            remainingM = if (arrived) 0.0 else remainingM,
            remainingS = remainingS,
            offRoute = !arrived && offRouteStreak >= OFF_ROUTE_FIXES,
            arrived = arrived,
        )
    }

    private fun windowedSnap(p: GeoPoint): Snap {
        val geometry = route.geometry
        val n = geometry.size
        if (n < 2) return Geo.snapToLine(p, geometry, cum)
        val from = max(0, min(lastSegment - 3, n - 2))
        val to = min(n, max(from + 2, lastSegment + 60))
        val s = Geo.snapToLine(p, geometry.subList(from, to))
        // If the window lost track (e.g. GPS jump), fall back to a global snap.
        if (s.distanceFromLineM > 60) {
            val global = Geo.snapToLine(p, geometry, cum)
            if (global.distanceFromLineM + 5 < s.distanceFromLineM) return global
        }
        val i = s.segmentIndex + from
        return Snap(s.point, i, s.fraction, s.distanceFromLineM, cum[i] + (cum[i + 1] - cum[i]) * s.fraction)
    }

    /** Voice cues due for [p] at [speedMps]; each cue fires once. Same thresholds as `cuesFor`. */
    fun cuesFor(p: NavProgress, speedMps: Double = 0.0): List<VoiceCue> {
        val out = ArrayList<VoiceCue>(1)
        val steps = route.steps
        if (p.arrived) {
            if (steps.isNotEmpty() && spokenCues.add("arrive")) {
                out.add(VoiceCue(steps.last(), CueStage.ARRIVE, 0.0, steps.size - 1))
            }
            return out
        }
        val next = p.nextStep ?: return out
        val idx = p.currentStepIndex + 1
        val v = max(speedMps, 8.0)
        val approachAt = (v * 25).coerceIn(200.0, 1500.0)
        val nowAt = (v * 6).coerceIn(40.0, 150.0)
        fun fire(stage: CueStage) {
            if (spokenCues.add("$idx:${stage.name}")) out.add(VoiceCue(next, stage, p.distanceToNextM, idx))
        }
        when {
            p.distanceToNextM <= nowAt -> {
                fire(CueStage.NOW)
                spokenCues.add("$idx:${CueStage.APPROACH.name}")
                spokenCues.add("$idx:${CueStage.PREPARE.name}")
            }
            p.distanceToNextM <= approachAt -> {
                fire(CueStage.APPROACH)
                spokenCues.add("$idx:${CueStage.PREPARE.name}")
            }
            p.distanceToNextM > approachAt + 200 -> fire(CueStage.PREPARE)
        }
        return out
    }
}
