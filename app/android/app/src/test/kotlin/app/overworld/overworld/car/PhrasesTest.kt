package app.overworld.overworld.car

import org.junit.Assert.assertEquals
import org.junit.Test

class PhrasesTest {
    private fun step(kind: ManeuverKind, street: String = "", exit: Int? = null) =
        RouteStep(kind, "turn", null, GeoPoint(0.0, 0.0), 100.0, 10.0, street, exit)

    @Test
    fun unitsMatchDartRounding() {
        assertEquals("95", Units.format(93.0, false).text)
        assertEquals(DistUnit.M, Units.format(93.0, false).unit)
        assertEquals("310", Units.format(306.0, false).text)
        assertEquals("1", Units.format(998.0, false).text)
        assertEquals(DistUnit.KM, Units.format(998.0, false).unit)
        assertEquals("1.2", Units.format(1234.0, false).text)
        assertEquals("13", Units.format(12_600.0, false).text)
        assertEquals("160", Units.format(50.0, true).text)
        assertEquals(DistUnit.FT, Units.format(50.0, true).unit)
        assertEquals("0.5", Units.format(800.0, true).text)
        assertEquals(DistUnit.MI, Units.format(800.0, true).unit)
        assertEquals("0", Units.format(Double.NaN, false).text)
    }

    @Test
    fun englishStages() {
        val s = step(ManeuverKind.LEFT, "Main St")
        assertEquals("Continue for 1.2 kilometers, then turn left", Phrases.phraseFor(VoiceCue(s, CueStage.PREPARE, 1234.0, 1), false, "en"))
        assertEquals("In 300 meters, turn left onto Main St", Phrases.phraseFor(VoiceCue(s, CueStage.APPROACH, 300.0, 1), false, "en"))
        assertEquals("Turn left onto Main St", Phrases.phraseFor(VoiceCue(s, CueStage.NOW, 40.0, 1), false, "en"))
        assertEquals("You have arrived at your destination", Phrases.phraseFor(VoiceCue(s, CueStage.ARRIVE, 0.0, 1), false, "en"))
        assertEquals("In 0.2 miles, turn left onto Main St", Phrases.phraseFor(VoiceCue(s, CueStage.APPROACH, 304.8, 1), true, "en"))
        assertEquals("In 160 feet, turn left onto Main St", Phrases.phraseFor(VoiceCue(s, CueStage.APPROACH, 50.0, 1), true, "en"))
    }

    @Test
    fun otherLanguages() {
        val s = step(ManeuverKind.RIGHT)
        assertEquals("In 300 Metern rechts abbiegen", Phrases.phraseFor(VoiceCue(s, CueStage.APPROACH, 300.0, 1), false, "de"))
        assertEquals("Tournez à droite maintenant", Phrases.phraseFor(VoiceCue(s, CueStage.NOW, 30.0, 1), false, "fr"))
        assertEquals("300 metre sonra sağa dönün", Phrases.phraseFor(VoiceCue(s, CueStage.APPROACH, 300.0, 1), false, "tr"))
        assertEquals("Gira a la derecha ahora", Phrases.phraseFor(VoiceCue(s, CueStage.NOW, 30.0, 1), false, "es"))
        assertEquals("Ora svolta a destra", Phrases.phraseFor(VoiceCue(s, CueStage.NOW, 30.0, 1), false, "it"))
        // Unknown language falls back to English; region suffixes are ignored.
        assertEquals("Turn right", Phrases.phraseFor(VoiceCue(s, CueStage.NOW, 30.0, 1), false, "xx"))
        assertEquals("Jetzt rechts abbiegen", Phrases.phraseFor(VoiceCue(s, CueStage.NOW, 30.0, 1), false, "de-AT"))
    }

    @Test
    fun roundabouts() {
        val s = step(ManeuverKind.ROUNDABOUT, exit = 2)
        assertEquals("At the roundabout, take the second exit", Phrases.phraseFor(VoiceCue(s, CueStage.NOW, 30.0, 1), false, "en"))
        assertEquals("Au rond-point, prenez la 2e sortie maintenant", Phrases.phraseFor(VoiceCue(s, CueStage.NOW, 30.0, 1), false, "fr"))
        assertEquals("Take the roundabout", Phrases.phraseFor(VoiceCue(step(ManeuverKind.ROUNDABOUT), CueStage.NOW, 30.0, 1), false, "en"))
    }

    @Test
    fun maneuverKinds() {
        assertEquals(ManeuverKind.DEPART, Maneuvers.kindOf("depart", "left"))
        assertEquals(ManeuverKind.ROUNDABOUT, Maneuvers.kindOf("rotary", null))
        assertEquals(ManeuverKind.SLIGHT_LEFT, Maneuvers.kindOf("fork", "left"))
        assertEquals(ManeuverKind.FORK, Maneuvers.kindOf("fork", "straight"))
        assertEquals(ManeuverKind.RAMP_RIGHT, Maneuvers.kindOf("off ramp", "slight right"))
        assertEquals(ManeuverKind.STRAIGHT, Maneuvers.kindOf("on ramp", "straight"))
        assertEquals(ManeuverKind.SHARP_RIGHT, Maneuvers.kindOf("turn", "sharp right"))
        assertEquals(ManeuverKind.UTURN, Maneuvers.kindOf("continue", "uturn"))
        assertEquals(ManeuverKind.STRAIGHT, Maneuvers.kindOf("new name", null))
    }
}
