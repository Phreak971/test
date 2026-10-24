package app.overworld.overworld.car

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/** A WGS84 coordinate. Pure Kotlin so it can be unit tested on the JVM. */
data class GeoPoint(val lat: Double, val lng: Double)

/** Result of snapping a point onto a polyline. */
data class Snap(
    val point: GeoPoint,
    val segmentIndex: Int,
    val fraction: Double,
    val distanceFromLineM: Double,
    val alongM: Double,
)

/** Google encoded polyline codec (precision 5 or 6) and small geo helpers. */
object Polyline {
    fun decode(encoded: String, precision: Int = 6): List<GeoPoint> {
        val factor = Math.pow(10.0, precision.toDouble())
        val out = ArrayList<GeoPoint>(encoded.length / 4)
        var index = 0
        var lat = 0L
        var lng = 0L
        val len = encoded.length
        while (index < len) {
            var result = 0L
            var shift = 0
            var b: Int
            do {
                if (index >= len) return out
                b = encoded[index++].code - 63
                result = result or ((b and 0x1f).toLong() shl shift)
                shift += 5
            } while (b >= 0x20)
            lat += if (result and 1L != 0L) (result shr 1).inv() else (result shr 1)

            result = 0L
            shift = 0
            do {
                if (index >= len) return out
                b = encoded[index++].code - 63
                result = result or ((b and 0x1f).toLong() shl shift)
                shift += 5
            } while (b >= 0x20)
            lng += if (result and 1L != 0L) (result shr 1).inv() else (result shr 1)

            out.add(GeoPoint(lat / factor, lng / factor))
        }
        return out
    }

    fun encode(points: List<GeoPoint>, precision: Int = 6): String {
        val factor = Math.pow(10.0, precision.toDouble())
        val sb = StringBuilder()
        var prevLat = 0L
        var prevLng = 0L
        fun put(v: Long) {
            var x = if (v < 0) (v shl 1).inv() else (v shl 1)
            while (x >= 0x20) {
                sb.append(((0x20L or (x and 0x1f)) + 63).toInt().toChar())
                x = x shr 5
            }
            sb.append((x + 63).toInt().toChar())
        }
        for (p in points) {
            val lat = Math.round(p.lat * factor)
            val lng = Math.round(p.lng * factor)
            put(lat - prevLat)
            put(lng - prevLng)
            prevLat = lat
            prevLng = lng
        }
        return sb.toString()
    }
}

object Geo {
    private const val EARTH_R = 6371008.8

    fun distanceM(a: GeoPoint, b: GeoPoint): Double {
        val dLat = Math.toRadians(b.lat - a.lat)
        val dLng = Math.toRadians(b.lng - a.lng)
        val la1 = Math.toRadians(a.lat)
        val la2 = Math.toRadians(b.lat)
        val h = sin(dLat / 2) * sin(dLat / 2) + cos(la1) * cos(la2) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * EARTH_R * atan2(sqrt(h), sqrt(max(0.0, 1 - h)))
    }

    /** Initial bearing a → b in degrees [0, 360). */
    fun bearingDeg(a: GeoPoint, b: GeoPoint): Double {
        val la1 = Math.toRadians(a.lat)
        val la2 = Math.toRadians(b.lat)
        val dLng = Math.toRadians(b.lng - a.lng)
        val y = sin(dLng) * cos(la2)
        val x = cos(la1) * sin(la2) - sin(la1) * cos(la2) * cos(dLng)
        val deg = Math.toDegrees(atan2(y, x))
        return (deg + 360.0) % 360.0
    }

    fun cumulativeDistances(line: List<GeoPoint>): DoubleArray {
        val out = DoubleArray(max(1, line.size))
        for (i in 1 until line.size) out[i] = out[i - 1] + distanceM(line[i - 1], line[i])
        return out
    }

    /**
     * Snaps [p] onto [line] using a local equirectangular projection per
     * segment (accurate to well under a metre at road scale).
     */
    fun snapToLine(p: GeoPoint, line: List<GeoPoint>, cumulative: DoubleArray? = null): Snap {
        require(line.isNotEmpty()) { "empty line" }
        if (line.size == 1) {
            return Snap(line[0], 0, 0.0, distanceM(p, line[0]), 0.0)
        }
        val cum = cumulative ?: cumulativeDistances(line)
        var best: Snap? = null
        val kLat = 111_320.0
        for (i in 0 until line.size - 1) {
            val a = line[i]
            val b = line[i + 1]
            val kLng = kLat * cos(Math.toRadians((a.lat + b.lat) / 2))
            val ax = 0.0
            val ay = 0.0
            val bx = (b.lng - a.lng) * kLng
            val by = (b.lat - a.lat) * kLat
            val px = (p.lng - a.lng) * kLng
            val py = (p.lat - a.lat) * kLat
            val len2 = bx * bx + by * by
            val t = if (len2 <= 0.0) 0.0 else min(1.0, max(0.0, ((px - ax) * bx + (py - ay) * by) / len2))
            val sx = bx * t
            val sy = by * t
            val d = sqrt((px - sx) * (px - sx) + (py - sy) * (py - sy))
            if (best == null || d < best.distanceFromLineM) {
                val pt = GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t)
                best = Snap(pt, i, t, d, cum[i] + (cum[i + 1] - cum[i]) * t)
            }
        }
        return best!!
    }
}
