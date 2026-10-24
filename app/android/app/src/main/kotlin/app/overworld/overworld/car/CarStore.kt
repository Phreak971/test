package app.overworld.overworld.car

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors

/** Voice settings synced from the phone (`voice` in the sync payload). */
data class CarVoiceSettings(val id: String = "classic", val name: String = "Navigator", val pitch: Double = 1.0, val rate: Double = 0.5)

/** Everything the car UI needs, as last synced from the phone. */
data class CarSnapshot(
    val synced: Boolean = false,
    val lightStyle: String? = null,
    val darkStyle: String? = null,
    val alwaysDark: Boolean = false,
    val premium: Boolean = false,
    val unit: String = "metric",
    val locale: String = "en",
    val voice: CarVoiceSettings = CarVoiceSettings(),
    val muted: Boolean = false,
    val places: List<CarPlace> = emptyList(),
    val history: List<CarPlace> = emptyList(),
    /** Bumped whenever icon PNGs were rewritten, so the map reloads them. */
    val iconsVersion: Long = 0,
) {
    val imperial: Boolean get() = Units.isImperial(unit)
}

/**
 * Persists the phone → car snapshot (see lib/car/car_bridge.dart) so the car
 * app works even when the Flutter UI was never opened in this process.
 *
 * Layout under `filesDir/car/`:
 *  - `state.json`         scalar/list fields + both style JSON strings
 *  - `icons/light/<name>.png`, `icons/dark/<name>.png`  style images
 *
 * Writes happen on a single background thread; listeners are notified on the
 * main thread with the new snapshot.
 */
object CarStore {
    private const val TAG = "OverworldCar"

    fun interface Listener {
        fun onSnapshot(snapshot: CarSnapshot)
    }

    fun interface PreviewListener {
        fun onPreview(place: CarPlace)
    }

    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor { r -> Thread(r, "overworld-car-store").apply { isDaemon = true } }
    private val listeners = CopyOnWriteArrayList<Listener>()
    private val lock = Any()

    @Volatile
    private var dir: File? = null

    @Volatile
    var snapshot: CarSnapshot = CarSnapshot()
        private set

    /** Set by the car session while connected; previews arriving otherwise are kept as pending. */
    @Volatile
    var previewListener: PreviewListener? = null

    @Volatile
    private var pendingPreview: CarPlace? = null

    /** Loads the persisted snapshot once (cheap; safe to call repeatedly). */
    fun init(context: Context) {
        if (dir != null) return
        synchronized(lock) {
            if (dir != null) return
            val d = File(context.applicationContext.filesDir, "car")
            d.mkdirs()
            snapshot = try {
                val f = File(d, "state.json")
                if (f.exists()) parseState(JSONObject(f.readText()), iconsVersion = f.lastModified()) else CarSnapshot()
            } catch (t: Throwable) {
                Log.w(TAG, "failed to read car state", t)
                CarSnapshot()
            }
            dir = d
        }
    }

    fun addListener(l: Listener) = listeners.addIfAbsent(l)
    fun removeListener(l: Listener) = listeners.remove(l)

    fun iconDir(dark: Boolean): File? = dir?.let { File(it, if (dark) "icons/dark" else "icons/light") }

    /**
     * Handles a `sync` call. [args] is the decoded MethodChannel map (icons as
     * ByteArray values). [done] runs on the main thread with null or an error.
     */
    fun sync(context: Context, args: Map<*, *>, done: (Throwable?) -> Unit) {
        init(context)
        io.execute {
            val error = try {
                val d = dir!!
                val lightIcons = args["lightIcons"] as? Map<*, *>
                val darkIcons = args["darkIcons"] as? Map<*, *>
                var iconsVersion = snapshot.iconsVersion
                if (lightIcons != null || darkIcons != null) {
                    writeIcons(File(d, "icons/light"), lightIcons)
                    writeIcons(File(d, "icons/dark"), darkIcons)
                    iconsVersion = System.currentTimeMillis()
                }
                val state = toStateJson(args)
                val tmp = File(d, "state.json.tmp")
                tmp.writeText(state.toString())
                val target = File(d, "state.json")
                if (!tmp.renameTo(target)) {
                    target.delete()
                    if (!tmp.renameTo(target)) throw java.io.IOException("rename failed")
                }
                val snap = parseState(state, iconsVersion)
                snapshot = snap
                main.post { for (l in listeners) runCatching { l.onSnapshot(snap) }.onFailure { Log.w(TAG, "listener", it) } }
                null
            } catch (t: Throwable) {
                Log.w(TAG, "car sync failed", t)
                t
            }
            main.post { done(error) }
        }
    }

    /**
     * Car-side mute toggle (main thread). Persisted locally; the phone's next
     * sync wins if its setting differs.
     */
    fun setMuted(muted: Boolean) {
        val snap = snapshot.copy(muted = muted)
        snapshot = snap
        for (l in listeners) runCatching { l.onSnapshot(snap) }
        val d = dir ?: return
        io.execute {
            try {
                val f = File(d, "state.json")
                if (f.exists()) {
                    val o = JSONObject(f.readText()).put("muted", muted)
                    val tmp = File(d, "state.json.tmp")
                    tmp.writeText(o.toString())
                    if (!tmp.renameTo(f)) {
                        f.delete()
                        tmp.renameTo(f)
                    }
                }
            } catch (t: Throwable) {
                Log.w(TAG, "failed to persist mute", t)
            }
        }
    }

    /** Handles a `previewRoute` call (main thread). */
    fun requestPreview(args: Map<*, *>) {
        val place = placeFrom(args) ?: return
        val l = previewListener
        if (l != null) l.onPreview(place) else pendingPreview = place
    }

    /** Returns and clears a preview requested while no car session was connected. */
    fun takePendingPreview(): CarPlace? {
        val p = pendingPreview
        pendingPreview = null
        return p
    }

    private fun writeIcons(target: File, icons: Map<*, *>?) {
        if (icons == null) return
        val tmp = File(target.parentFile, target.name + ".tmp")
        tmp.deleteRecursively()
        tmp.mkdirs()
        for ((k, v) in icons) {
            val name = k as? String ?: continue
            val bytes = v as? ByteArray ?: continue
            if (!safeName(name)) continue
            File(tmp, "$name.png").writeBytes(bytes)
        }
        synchronized(lock) {
            target.deleteRecursively()
            if (!tmp.renameTo(target)) {
                tmp.copyRecursively(target, overwrite = true)
                tmp.deleteRecursively()
            }
        }
    }

    private fun safeName(n: String) = n.isNotEmpty() && n.length < 128 && n.all { it.isLetterOrDigit() || it == '-' || it == '_' || it == '.' } && !n.contains("..")

    private fun toStateJson(a: Map<*, *>): JSONObject {
        val o = JSONObject()
        o.put("lightStyle", a["lightStyle"] as? String ?: JSONObject.NULL)
        o.put("darkStyle", a["darkStyle"] as? String ?: JSONObject.NULL)
        o.put("alwaysDark", a["alwaysDark"] as? Boolean ?: false)
        o.put("premium", a["premium"] as? Boolean ?: false)
        o.put("unit", a["unit"] as? String ?: "metric")
        o.put("locale", a["locale"] as? String ?: "en")
        o.put("muted", a["muted"] as? Boolean ?: false)
        val v = a["voice"] as? Map<*, *>
        o.put(
            "voice",
            JSONObject()
                .put("id", v?.get("id") as? String ?: "classic")
                .put("name", v?.get("name") as? String ?: "Navigator")
                .put("pitch", (v?.get("pitch") as? Number)?.toDouble() ?: 1.0)
                .put("rate", (v?.get("rate") as? Number)?.toDouble() ?: 0.5),
        )
        o.put("places", placesJson(a["places"] as? List<*>))
        o.put("history", placesJson(a["history"] as? List<*>))
        return o
    }

    private fun placesJson(list: List<*>?): JSONArray {
        val arr = JSONArray()
        for (item in list.orEmpty()) {
            val p = placeFrom(item as? Map<*, *> ?: continue) ?: continue
            arr.put(
                JSONObject()
                    .put("id", p.id ?: JSONObject.NULL)
                    .put("name", p.name)
                    .put("lat", p.lat)
                    .put("lng", p.lng)
                    .put("address", p.address ?: JSONObject.NULL)
                    .put("isHome", p.isHome),
            )
        }
        return arr
    }

    private fun placeFrom(m: Map<*, *>): CarPlace? {
        val lat = (m["lat"] as? Number)?.toDouble() ?: return null
        val lng = (m["lng"] as? Number)?.toDouble() ?: return null
        return CarPlace(
            name = (m["name"] as? String)?.ifBlank { null } ?: "%.5f, %.5f".format(java.util.Locale.US, lat, lng),
            lat = lat,
            lng = lng,
            address = (m["address"] as? String)?.ifBlank { null },
            isHome = m["isHome"] as? Boolean ?: false,
            id = m["id"]?.toString(),
        )
    }

    internal fun parseState(o: JSONObject, iconsVersion: Long): CarSnapshot {
        fun places(key: String): List<CarPlace> {
            val arr = o.optJSONArray(key) ?: return emptyList()
            return (0 until arr.length()).mapNotNull { i ->
                val p = arr.optJSONObject(i) ?: return@mapNotNull null
                if (!p.has("lat") || !p.has("lng")) return@mapNotNull null
                CarPlace(
                    name = p.optString("name"),
                    lat = p.getDouble("lat"),
                    lng = p.getDouble("lng"),
                    address = if (p.isNull("address")) null else p.optString("address").ifBlank { null },
                    isHome = p.optBoolean("isHome"),
                    id = if (p.isNull("id")) null else p.optString("id"),
                )
            }
        }
        val v = o.optJSONObject("voice")
        return CarSnapshot(
            synced = true,
            lightStyle = if (o.isNull("lightStyle")) null else o.optString("lightStyle").ifBlank { null },
            darkStyle = if (o.isNull("darkStyle")) null else o.optString("darkStyle").ifBlank { null },
            alwaysDark = o.optBoolean("alwaysDark"),
            premium = o.optBoolean("premium"),
            unit = o.optString("unit", "metric"),
            locale = o.optString("locale", "en"),
            voice = CarVoiceSettings(
                id = v?.optString("id", "classic") ?: "classic",
                name = v?.optString("name", "Navigator") ?: "Navigator",
                pitch = v?.optDouble("pitch", 1.0) ?: 1.0,
                rate = v?.optDouble("rate", 0.5) ?: 0.5,
            ),
            muted = o.optBoolean("muted"),
            places = places("places"),
            history = places("history"),
            iconsVersion = iconsVersion,
        )
    }
}
