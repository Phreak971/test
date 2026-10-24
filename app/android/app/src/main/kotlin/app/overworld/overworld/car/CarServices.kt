package app.overworld.overworld.car

import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future
import kotlin.math.cos

/** No route between the two points (OSRM `code` != Ok, or no routes). */
class NoRouteException(val code: String) : IOException("No route: $code")

/**
 * Network services for the car UI: Photon search, Nominatim nearby, OSRM
 * routing. Requests run on a small background pool; callbacks are delivered
 * on the main thread unless the returned [Future] was cancelled.
 */
class CarServices {
    private val executor: ExecutorService = Executors.newFixedThreadPool(2) { r ->
        Thread(r, "overworld-car-net").apply { isDaemon = true }
    }
    private val main = Handler(Looper.getMainLooper())

    private fun <T> run(work: () -> T, cb: (Result<T>) -> Unit): Future<*> {
        var self: Future<*>? = null
        val f = executor.submit {
            val r = try {
                Result.success(work())
            } catch (t: Throwable) {
                Log.w(TAG, "request failed", t)
                Result.failure(t)
            }
            main.post { if (self?.isCancelled != true) cb(r) }
        }
        self = f
        return f
    }

    fun search(query: String, near: GeoPoint?, lang: String?, cb: (Result<List<CarPlace>>) -> Unit): Future<*> =
        run({ parsePhoton(get(photonUrl(query, near, lang))) }, cb)

    fun nearby(amenity: String, center: GeoPoint, radiusKm: Double = 8.0, cb: (Result<List<CarPlace>>) -> Unit): Future<*> =
        run({
            val places = parseNominatim(get(nominatimUrl(amenity, center, radiusKm)))
            places.sortedBy { Geo.distanceM(center, it.point) }
        }, cb)

    fun route(from: GeoPoint, to: GeoPoint, headingDeg: Double?, cb: (Result<Route>) -> Unit): Future<*> =
        run({ parseOsrm(get(osrmUrl(from, to, headingDeg))) }, cb)

    fun shutdown() {
        executor.shutdownNow()
        main.removeCallbacksAndMessages(null)
    }

    companion object {
        private const val TAG = "OverworldCar"
        private const val USER_AGENT = "Overworld/1.0"

        fun photonUrl(query: String, near: GeoPoint?, lang: String?): String {
            val sb = StringBuilder("https://photon.komoot.io/api/?q=")
                .append(URLEncoder.encode(query, "UTF-8"))
                .append("&limit=10")
            if (near != null) sb.append("&lat=").append(fmt(near.lat)).append("&lon=").append(fmt(near.lng))
            // Photon only knows a few languages; others fall back to local names.
            if (lang in setOf("en", "de", "fr")) sb.append("&lang=").append(lang)
            return sb.toString()
        }

        fun nominatimUrl(amenity: String, c: GeoPoint, radiusKm: Double): String {
            val dLat = radiusKm / 111.32
            val dLng = radiusKm / (111.32 * cos(Math.toRadians(c.lat)).coerceAtLeast(0.01))
            val viewbox = "${fmt(c.lng - dLng)},${fmt(c.lat + dLat)},${fmt(c.lng + dLng)},${fmt(c.lat - dLat)}"
            return "https://nominatim.openstreetmap.org/search?amenity=" + URLEncoder.encode(amenity, "UTF-8") +
                "&format=jsonv2&limit=15&bounded=1&viewbox=" + viewbox
        }

        fun osrmUrl(from: GeoPoint, to: GeoPoint, headingDeg: Double?): String {
            val sb = StringBuilder("https://router.project-osrm.org/route/v1/driving/")
                .append(fmt(from.lng)).append(',').append(fmt(from.lat)).append(';')
                .append(fmt(to.lng)).append(',').append(fmt(to.lat))
                .append("?overview=full&geometries=polyline6&steps=true&alternatives=false")
            if (headingDeg != null) {
                // Prefer continuing in the current direction when rerouting.
                val h = ((Math.round(headingDeg) % 360) + 360) % 360
                sb.append("&bearings=").append(h).append(",60;&radiuses=50;unlimited")
            }
            return sb.toString()
        }

        private fun fmt(v: Double) = String.format(Locale.US, "%.6f", v)

        fun get(url: String): String {
            val conn = URL(url).openConnection() as HttpURLConnection
            try {
                conn.connectTimeout = 10_000
                conn.readTimeout = 15_000
                conn.setRequestProperty("User-Agent", USER_AGENT)
                conn.setRequestProperty("Accept", "application/json")
                val code = conn.responseCode
                val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                val body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
                // OSRM answers 400 with a JSON `code` for NoRoute etc.; let the parser report it.
                if (code !in 200..299 && !(code == 400 && url.contains("router.project-osrm.org"))) {
                    throw IOException("HTTP $code for ${URL(url).host}")
                }
                return body
            } finally {
                conn.disconnect()
            }
        }

        // ---- Parsing (pure; unit tested with real org.json) ----

        fun parsePhoton(body: String): List<CarPlace> {
            val features = JSONObject(body).optJSONArray("features") ?: return emptyList()
            val out = ArrayList<CarPlace>(features.length())
            for (i in 0 until features.length()) {
                val f = features.optJSONObject(i) ?: continue
                val coords = f.optJSONObject("geometry")?.optJSONArray("coordinates") ?: continue
                if (coords.length() < 2) continue
                val p = f.optJSONObject("properties") ?: JSONObject()
                val street = p.str("street")
                val house = p.str("housenumber")
                val streetLine = listOfNotNull(street, house).joinToString(" ").ifEmpty { null }
                val name = p.str("name") ?: streetLine ?: p.str("city") ?: continue
                val address = listOfNotNull(
                    streetLine?.takeIf { it != name },
                    p.str("city")?.takeIf { it != name },
                    p.str("country"),
                ).joinToString(", ").ifEmpty { null }
                out.add(CarPlace(name = name, lat = coords.getDouble(1), lng = coords.getDouble(0), address = address))
            }
            return out
        }

        fun parseNominatim(body: String): List<CarPlace> {
            val arr = JSONArray(body)
            val out = ArrayList<CarPlace>(arr.length())
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val lat = o.optString("lat").toDoubleOrNull() ?: continue
                val lon = o.optString("lon").toDoubleOrNull() ?: continue
                val display = o.str("display_name") ?: ""
                val parts = display.split(", ")
                val name = o.str("name") ?: parts.firstOrNull()?.takeIf { it.isNotBlank() } ?: continue
                val address = parts.filter { it != name }.take(3).joinToString(", ").ifEmpty { null }
                out.add(CarPlace(name = name, lat = lat, lng = lon, address = address, id = o.opt("osm_id")?.toString()))
            }
            return out
        }

        fun parseOsrm(body: String): Route {
            val json = JSONObject(body)
            val code = json.optString("code", "Error")
            val routes = json.optJSONArray("routes")
            if (code != "Ok" || routes == null || routes.length() == 0) throw NoRouteException(code)
            val r = routes.getJSONObject(0)
            val geometry = Polyline.decode(r.getString("geometry"), 6)
            if (geometry.size < 2) throw NoRouteException("EmptyGeometry")
            val steps = ArrayList<RouteStep>()
            val legs = r.optJSONArray("legs") ?: JSONArray()
            for (li in 0 until legs.length()) {
                val ss = legs.getJSONObject(li).optJSONArray("steps") ?: continue
                for (si in 0 until ss.length()) {
                    val s = ss.getJSONObject(si)
                    val m = s.getJSONObject("maneuver")
                    val loc = m.getJSONArray("location")
                    val type = m.optString("type", "turn")
                    val modifier = m.str("modifier")
                    steps.add(
                        RouteStep(
                            kind = Maneuvers.kindOf(type, modifier),
                            osrmType = type,
                            osrmModifier = modifier,
                            location = GeoPoint(loc.getDouble(1), loc.getDouble(0)),
                            distanceM = s.optDouble("distance", 0.0),
                            durationS = s.optDouble("duration", 0.0),
                            streetName = streetName(s),
                            roundaboutExit = if (m.has("exit") && !m.isNull("exit")) m.optInt("exit") else null,
                            drivingSide = s.str("driving_side") ?: "right",
                        ),
                    )
                }
            }
            if (steps.isEmpty()) throw NoRouteException("NoSteps")
            return Route(geometry, r.optDouble("distance", 0.0), r.optDouble("duration", 0.0), steps)
        }

        private fun streetName(step: JSONObject): String {
            step.str("name")?.let { return it }
            step.str("ref")?.let { return it.split(';').first().trim() }
            return step.str("destinations") ?: ""
        }

        /** Non-blank string value or null (org.json returns "null" for JSON nulls via optString). */
        private fun JSONObject.str(key: String): String? {
            if (!has(key) || isNull(key)) return null
            return optString(key).trim().ifEmpty { null }
        }
    }
}
