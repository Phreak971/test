package app.overworld.overworld.car

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class CarServicesParseTest {
    @Test
    fun parsesOsrmRoute() {
        val line = listOf(GeoPoint(52.5, 13.4), GeoPoint(52.501, 13.4), GeoPoint(52.501, 13.402))
        val geom = Polyline.encode(line, 6)
        val s0 = Polyline.encode(line.subList(0, 2), 6)
        val s1 = Polyline.encode(line.subList(1, 3), 6)
        val json = """
            {"code":"Ok","routes":[{"geometry":"${geom.replace("\\", "\\\\")}","distance":250.5,"duration":42.0,
              "legs":[{"steps":[
                {"geometry":"${s0.replace("\\", "\\\\")}","distance":111.2,"duration":20,"name":"","ref":"B 2;B 5","driving_side":"right",
                 "maneuver":{"type":"depart","location":[13.4,52.5],"bearing_after":0}},
                {"geometry":"${s1.replace("\\", "\\\\")}","distance":139.3,"duration":22,"name":"Unter den Linden","driving_side":"right",
                 "maneuver":{"type":"roundabout","modifier":"right","exit":3,"location":[13.4,52.501]}},
                {"geometry":"","distance":0,"duration":0,"name":null,"destinations":"Mitte",
                 "maneuver":{"type":"arrive","location":[13.402,52.501]}}
              ]}]}]}
        """.trimIndent()
        val r = CarServices.parseOsrm(json)
        assertEquals(3, r.geometry.size)
        assertEquals(52.501, r.geometry[2].lat, 1e-6)
        assertEquals(13.402, r.geometry[2].lng, 1e-6)
        assertEquals(250.5, r.distanceM, 1e-9)
        assertEquals(3, r.steps.size)
        assertEquals(ManeuverKind.DEPART, r.steps[0].kind)
        assertEquals("B 2", r.steps[0].streetName)
        assertEquals(ManeuverKind.ROUNDABOUT, r.steps[1].kind)
        assertEquals(3, r.steps[1].roundaboutExit)
        assertEquals("right", r.steps[1].osrmModifier)
        assertEquals("Unter den Linden", r.steps[1].streetName)
        assertEquals(52.501, r.steps[1].location.lat, 1e-9)
        assertEquals("Mitte", r.steps[2].streetName)
        assertNull(r.steps[2].roundaboutExit)
        assertNull(r.steps[2].osrmModifier)
    }

    @Test
    fun osrmNoRoute() {
        try {
            CarServices.parseOsrm("""{"code":"NoRoute","message":"Impossible route between points","routes":[]}""")
            fail("expected NoRouteException")
        } catch (e: NoRouteException) {
            assertEquals("NoRoute", e.code)
        }
    }

    @Test
    fun parsesPhoton() {
        val json = """
            {"type":"FeatureCollection","features":[
              {"type":"Feature","geometry":{"type":"Point","coordinates":[13.3777,52.5163]},
               "properties":{"name":"Brandenburger Tor","street":"Pariser Platz","city":"Berlin","country":"Deutschland"}},
              {"type":"Feature","geometry":{"type":"Point","coordinates":[2.29,48.85]},
               "properties":{"street":"Rue de Rivoli","housenumber":"10","city":"Paris","country":"France"}},
              {"type":"Feature","geometry":{"type":"Point","coordinates":[1.0]},"properties":{"name":"broken"}}
            ]}
        """.trimIndent()
        val out = CarServices.parsePhoton(json)
        assertEquals(2, out.size)
        assertEquals("Brandenburger Tor", out[0].name)
        assertEquals(52.5163, out[0].lat, 1e-9)
        assertEquals(13.3777, out[0].lng, 1e-9)
        assertEquals("Pariser Platz, Berlin, Deutschland", out[0].address)
        assertEquals("Rue de Rivoli 10", out[1].name)
        assertEquals("Paris, France", out[1].address)
    }

    @Test
    fun parsesNominatim() {
        val json = """
            [{"place_id":1,"osm_id":42,"lat":"52.52","lon":"13.40","name":"Tankstelle Mitte",
              "display_name":"Tankstelle Mitte, Hauptstraße, Mitte, Berlin, 10115, Deutschland"},
             {"lat":"52.53","lon":"13.41","name":"","display_name":"Aral, Torstraße, Berlin"},
             {"lat":"x","lon":"13.41","name":"bad"}]
        """.trimIndent()
        val out = CarServices.parseNominatim(json)
        assertEquals(2, out.size)
        assertEquals("Tankstelle Mitte", out[0].name)
        assertEquals("Hauptstraße, Mitte, Berlin", out[0].address)
        assertEquals("42", out[0].id)
        assertEquals("Aral", out[1].name)
        assertTrue(out[1].address!!.startsWith("Torstraße"))
    }

    @Test
    fun buildsUrls() {
        val u = CarServices.nominatimUrl("fuel", GeoPoint(52.0, 13.0), 8.0)
        assertTrue(u.startsWith("https://nominatim.openstreetmap.org/search?amenity=fuel&format=jsonv2&limit=15&bounded=1&viewbox="))
        val vb = u.substringAfter("viewbox=").split(',').map { it.toDouble() }
        assertTrue(vb[0] < 13.0 && vb[2] > 13.0) // minLon < lon < maxLon
        assertTrue(vb[1] > 52.0 && vb[3] < 52.0) // maxLat > lat > minLat
        assertEquals(
            "https://router.project-osrm.org/route/v1/driving/13.000000,52.000000;13.100000,52.100000?overview=full&geometries=polyline6&steps=true&alternatives=false",
            CarServices.osrmUrl(GeoPoint(52.0, 13.0), GeoPoint(52.1, 13.1), null),
        )
        assertTrue(CarServices.photonUrl("Café Zürich", GeoPoint(1.0, 2.0), "de").contains("q=Caf%C3%A9+Z%C3%BCrich&limit=10&lat=1.000000&lon=2.000000&lang=de"))
    }
}
