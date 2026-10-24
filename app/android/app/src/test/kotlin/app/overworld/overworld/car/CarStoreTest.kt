package app.overworld.overworld.car

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CarStoreTest {
    @Test
    fun parsesPersistedState() {
        val o = JSONObject(
            """
            {"lightStyle":"{\"version\":8}","darkStyle":null,"alwaysDark":true,"premium":true,"unit":"imperial","locale":"de",
             "muted":false,"voice":{"id":"ranger","name":"Frontier Ranger","pitch":0.75,"rate":0.42},
             "places":[{"id":"h","name":"Home","lat":1.5,"lng":2.5,"address":null,"isHome":true}],
             "history":[{"id":null,"name":"Shop","lat":3.0,"lng":4.0,"address":"Main 1","isHome":false},{"name":"no coords"}]}
            """.trimIndent(),
        )
        val s = CarStore.parseState(o, iconsVersion = 7)
        assertTrue(s.synced)
        assertEquals("{\"version\":8}", s.lightStyle)
        assertNull(s.darkStyle)
        assertTrue(s.alwaysDark && s.premium && s.imperial)
        assertEquals("de", s.locale)
        assertEquals(0.42, s.voice.rate, 1e-9)
        assertEquals("Frontier Ranger", s.voice.name)
        assertEquals(1, s.places.size)
        assertTrue(s.places[0].isHome)
        assertNull(s.places[0].address)
        assertEquals(1, s.history.size)
        assertNull(s.history[0].id)
        assertEquals("Main 1", s.history[0].address)
        assertEquals(7L, s.iconsVersion)
    }
}
