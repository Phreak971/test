package app.overworld.overworld.car

import org.junit.Assert.assertEquals
import org.junit.Test

class PolylineTest {
    @Test
    fun decodesGoogleReferencePrecision5() {
        val pts = Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@", precision = 5)
        assertEquals(3, pts.size)
        assertEquals(38.5, pts[0].lat, 1e-9)
        assertEquals(-120.2, pts[0].lng, 1e-9)
        assertEquals(40.7, pts[1].lat, 1e-9)
        assertEquals(-120.95, pts[1].lng, 1e-9)
        assertEquals(43.252, pts[2].lat, 1e-9)
        assertEquals(-126.453, pts[2].lng, 1e-9)
    }

    @Test
    fun roundTripsPrecision6() {
        val pts = listOf(GeoPoint(52.520008, 13.404954), GeoPoint(52.5163, 13.3777), GeoPoint(-33.868820, 151.209296))
        val decoded = Polyline.decode(Polyline.encode(pts, 6), 6)
        assertEquals(pts.size, decoded.size)
        for (i in pts.indices) {
            assertEquals(pts[i].lat, decoded[i].lat, 1e-6)
            assertEquals(pts[i].lng, decoded[i].lng, 1e-6)
        }
    }

    @Test
    fun truncatedInputDoesNotThrow() {
        val enc = Polyline.encode(listOf(GeoPoint(1.0, 2.0), GeoPoint(3.0, 4.0)), 6)
        val pts = Polyline.decode(enc.dropLast(2), 6)
        assertEquals(1, pts.size)
    }

    @Test
    fun geoHelpers() {
        val a = GeoPoint(0.0, 0.0)
        val b = GeoPoint(0.0, 1.0)
        assertEquals(111_195.0, Geo.distanceM(a, b), 50.0)
        assertEquals(90.0, Geo.bearingDeg(a, b), 1e-6)
        assertEquals(0.0, Geo.bearingDeg(a, GeoPoint(1.0, 0.0)), 1e-6)
        val snap = Geo.snapToLine(GeoPoint(0.0005, 0.5), listOf(a, b))
        assertEquals(0, snap.segmentIndex)
        assertEquals(0.5, snap.fraction, 1e-3)
        assertEquals(55.6, snap.distanceFromLineM, 1.0)
        assertEquals(Geo.distanceM(a, b) / 2, snap.alongM, 100.0)
    }
}
