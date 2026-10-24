package app.overworld.overworld.car

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ProgressTest {
    // North along lng 0 for ~1.1 km, then east along lat 0.01 for ~1.1 km.
    private val corner = GeoPoint(0.01, 0.0)
    private val end = GeoPoint(0.01, 0.01)
    private val geometry: List<GeoPoint> = buildList {
        for (i in 0..10) add(GeoPoint(i * 0.001, 0.0))
        for (i in 1..10) add(GeoPoint(0.01, i * 0.001))
    }
    private val leg = Geo.distanceM(GeoPoint(0.0, 0.0), corner)

    private fun step(kind: ManeuverKind, type: String, mod: String?, at: GeoPoint, dist: Double, street: String = "") =
        RouteStep(kind, type, mod, at, dist, dist / 10.0, street, null)

    private val route = Route(
        geometry = geometry,
        distanceM = leg * 2,
        durationS = leg * 2 / 10.0,
        steps = listOf(
            step(ManeuverKind.DEPART, "depart", null, GeoPoint(0.0, 0.0), leg, "North St"),
            step(ManeuverKind.RIGHT, "turn", "right", corner, leg, "East St"),
            step(ManeuverKind.ARRIVE, "arrive", null, end, 0.0),
        ),
    )

    @Test
    fun tracksStepsAndDistances() {
        val t = ProgressTracker(route)
        val p0 = t.update(Fix(GeoPoint(0.0001, 0.00002)))
        assertEquals(0, p0.currentStepIndex)
        assertEquals(ManeuverKind.RIGHT, p0.nextStep?.kind)
        assertEquals(leg - 11.1, p0.distanceToNextM, 2.0)
        assertFalse(p0.offRoute)
        assertFalse(p0.arrived)
        // Snapped onto the line.
        assertEquals(0.0, p0.snapped.lng, 1e-9)

        val p1 = t.update(Fix(GeoPoint(0.005, 0.0)))
        assertEquals(leg / 2, p1.distanceToNextM, 2.0)
        assertEquals(0.0, p1.bearingDeg, 0.5)
        assertEquals(leg * 1.5, p1.remainingM, 3.0)
        // Duration: half of step 0 plus all of step 1.
        assertEquals(leg / 20 + leg / 10, p1.remainingS, 1.0)

        val p2 = t.update(Fix(GeoPoint(0.01, 0.003)))
        assertEquals(1, p2.currentStepIndex)
        assertEquals(ManeuverKind.ARRIVE, p2.nextStep?.kind)
        assertEquals(90.0, p2.bearingDeg, 0.5)
    }

    @Test
    fun offRouteAfterThreeFarFixes() {
        val t = ProgressTracker(route)
        t.update(Fix(GeoPoint(0.002, 0.0)))
        val far = GeoPoint(0.002, 0.002) // ~220 m east of the line
        assertFalse(t.update(Fix(far)).offRoute)
        assertFalse(t.update(Fix(far)).offRoute)
        assertTrue(t.update(Fix(far)).offRoute)
        // Back on the line resets.
        assertFalse(t.update(Fix(GeoPoint(0.0025, 0.0))).offRoute)
    }

    @Test
    fun arrivesWithin30m() {
        val t = ProgressTracker(route)
        t.update(Fix(GeoPoint(0.005, 0.0)))
        t.update(Fix(GeoPoint(0.01, 0.005)))
        val p = t.update(Fix(GeoPoint(0.01, 0.0098)))
        assertTrue(p.arrived)
        assertNull(p.nextStep)
        assertEquals(0.0, p.remainingM, 0.0)
        val cues = t.cuesFor(p)
        assertEquals(1, cues.size)
        assertEquals(CueStage.ARRIVE, cues[0].stage)
        assertTrue(t.cuesFor(p).isEmpty())
    }

    @Test
    fun cuesFireOncePerStage() {
        val t = ProgressTracker(route)
        // ~1.1 km before the turn at 8 m/s: approachAt = 200 m → prepare fires.
        val p0 = t.update(Fix(GeoPoint(0.0, 0.0)))
        val c0 = t.cuesFor(p0, 8.0)
        assertEquals(listOf(CueStage.PREPARE), c0.map { it.stage })
        assertTrue(t.cuesFor(t.update(Fix(GeoPoint(0.0005, 0.0))), 8.0).isEmpty())
        // 150 m before the turn → approach.
        val p1 = t.update(Fix(GeoPoint(0.01 - 150 / 111_195.0, 0.0)))
        assertEquals(listOf(CueStage.APPROACH), t.cuesFor(p1, 8.0).map { it.stage })
        // 30 m before → now.
        val p2 = t.update(Fix(GeoPoint(0.01 - 30 / 111_195.0, 0.0)))
        val c2 = t.cuesFor(p2, 8.0)
        assertEquals(listOf(CueStage.NOW), c2.map { it.stage })
        assertNotNull(c2[0].step)
        assertEquals(ManeuverKind.RIGHT, c2[0].step.kind)
        assertTrue(t.cuesFor(p2, 8.0).isEmpty())
    }
}
