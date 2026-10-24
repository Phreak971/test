package app.overworld.overworld.car

import android.app.Presentation
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Point
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.util.DisplayMetrics
import android.util.Log
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapLibreMapOptions
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.sources.GeoJsonSource
import java.io.File
import java.util.Locale
import kotlin.math.ln
import kotlin.math.max

/**
 * Renders the MapLibre map onto the Android Auto surface.
 *
 * The host hands us a [android.view.Surface]; we wrap it in a private
 * [VirtualDisplay] and show a [Presentation] hosting a regular [MapView] on
 * it. Pan/zoom gestures arrive through [SurfaceCallback] (the car screen has
 * no touch events for our views) and are applied to the camera directly.
 *
 * All methods are called on the main thread.
 */
class MapSurfaceRenderer(private val carContext: CarContext) : SurfaceCallback {
    private var virtualDisplay: VirtualDisplay? = null
    private var presentation: Presentation? = null
    private var mapView: MapView? = null
    private var map: MapLibreMap? = null
    private var style: Style? = null
    private var generation = 0
    private var surfaceWidth = 0
    private var surfaceHeight = 0
    private var visibleArea: Rect? = null
    private var stableArea: Rect? = null

    private var styleKey: String? = null
    private var snapshot: CarSnapshot = CarStore.snapshot
    private var darkMode = false

    // Overlay state (re-applied after every style load).
    private var user: GeoPoint? = null
    private var userBearing = 0.0
    private var routeLine: List<GeoPoint> = emptyList()
    private var destination: CarPlace? = null
    private var placesJson: String = EMPTY_FC

    /** When true the camera follows the user; panning turns it off, recenter turns it on. */
    var following = true
        private set

    /** Navigation camera (tilted, heading-up, puck low on screen) vs. north-up browse camera. */
    var navigating = false
        set(value) {
            field = value
            if (following) followCamera(animated = true)
        }

    /** Notified when [following] changes so screens can show/hide "recenter". */
    var onFollowingChanged: ((Boolean) -> Unit)? = null

    fun attach() {
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(this)
    }

    // ---- SurfaceCallback ----

    override fun onSurfaceAvailable(surfaceContainer: SurfaceContainer) {
        val surface = surfaceContainer.surface
        if (surface == null || surfaceContainer.width <= 0 || surfaceContainer.height <= 0) {
            Log.w(TAG, "surface not usable")
            return
        }
        releaseMap()
        surfaceWidth = surfaceContainer.width
        surfaceHeight = surfaceContainer.height
        try {
            MapLibre.getInstance(carContext)
            val dm = carContext.getSystemService(DisplayManager::class.java)
            val vd = dm.createVirtualDisplay(
                "OverworldCarMap",
                surfaceContainer.width,
                surfaceContainer.height,
                surfaceContainer.dpi,
                surface,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY,
            )
            virtualDisplay = vd
            val pres = Presentation(carContext, vd.display)
            val options = MapLibreMapOptions.createFromAttributes(pres.context)
                .logoEnabled(false)
                .compassEnabled(false)
                .attributionEnabled(true)
                .textureMode(false)
            val mv = MapView(pres.context, options)
            mv.onCreate(null)
            pres.setContentView(mv)
            pres.show()
            mv.onStart()
            mv.onResume()
            presentation = pres
            mapView = mv
            val gen = ++generation
            mv.getMapAsync { m -> if (gen == generation) onMapReady(m) }
        } catch (t: Throwable) {
            Log.e(TAG, "failed to create car map", t)
            releaseMap()
        }
    }

    override fun onVisibleAreaChanged(visibleArea: Rect) {
        this.visibleArea = Rect(visibleArea)
        if (following) followCamera(animated = false)
    }

    override fun onStableAreaChanged(stableArea: Rect) {
        this.stableArea = Rect(stableArea)
    }

    override fun onSurfaceDestroyed(surfaceContainer: SurfaceContainer) {
        releaseMap()
    }

    override fun onScroll(distanceX: Float, distanceY: Float) {
        val m = map ?: return
        setFollowing(false)
        m.cancelTransitions()
        m.scrollBy(-distanceX, -distanceY, 0)
    }

    override fun onFling(velocityX: Float, velocityY: Float) {
        val m = map ?: return
        setFollowing(false)
        // A short glide in the fling direction.
        m.scrollBy(velocityX * 0.15f, velocityY * 0.15f, 300)
    }

    override fun onScale(focusX: Float, focusY: Float, scaleFactor: Float) {
        if (scaleFactor <= 0f) return
        val delta = ln(scaleFactor.toDouble()) / ln(2.0)
        zoomBy(delta, if (focusX < 0 || focusY < 0) null else Point(focusX.toInt(), focusY.toInt()))
    }

    // ---- Public controls ----

    fun zoomBy(delta: Double, focus: Point? = null) {
        val m = map ?: return
        val f = focus ?: visibleCenter()
        if (following) {
            // Keep following; just change the follow zoom.
            followZoomOverride = (m.cameraPosition.zoom + delta).coerceIn(3.0, 19.5)
            followCamera(animated = true)
            return
        }
        m.easeCamera(CameraUpdateFactory.zoomBy(delta, f), 250)
    }

    fun recenter() {
        followZoomOverride = null
        setFollowing(true)
        followCamera(animated = true)
    }

    /** Fit the camera to [points] inside the visible area (route preview). */
    fun showOverview(points: List<GeoPoint>) {
        val m = map ?: run { pendingOverview = points; return }
        if (points.size < 2) {
            points.firstOrNull()?.let { m.easeCamera(CameraUpdateFactory.newLatLngZoom(LatLng(it.lat, it.lng), 14.0), 600) }
            setFollowing(false)
            return
        }
        setFollowing(false)
        val b = LatLngBounds.Builder()
        for (p in points) b.include(LatLng(p.lat, p.lng))
        val pad = padding()
        val margin = 48
        try {
            m.easeCamera(
                CameraUpdateFactory.newLatLngBounds(
                    b.build(),
                    pad[0].toInt() + margin, pad[1].toInt() + margin, pad[2].toInt() + margin, pad[3].toInt() + margin,
                ),
                700,
            )
        } catch (t: Throwable) {
            Log.w(TAG, "overview failed", t)
        }
    }

    fun updateUser(p: GeoPoint, bearing: Double) {
        user = p
        userBearing = bearing
        pushUser()
        if (following) followCamera(animated = true)
    }

    fun setRoute(line: List<GeoPoint>, dest: CarPlace?) {
        routeLine = line
        destination = dest
        pushRoute()
    }

    fun clearRoute() = setRoute(emptyList(), null)

    fun setPlaces(places: List<CarPlace>) {
        placesJson = buildString {
            append("{\"type\":\"FeatureCollection\",\"features\":[")
            places.forEachIndexed { i, p ->
                if (i > 0) append(',')
                append("{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[")
                append(num(p.lng)).append(',').append(num(p.lat)).append("]},\"properties\":{")
                append("\"id\":").append(jsonString(p.id ?: "car-$i")).append(',')
                append("\"name\":").append(jsonString(p.name)).append(',')
                append("\"icon\":\"").append(if (p.isHome) "home" else "star").append("\"}}")
            }
            append("]}")
        }
        setSource(SRC_PLACES, placesJson)
    }

    /** Applies a new snapshot and/or car day-night mode; reloads the style if it changed. */
    fun applyTheme(snapshot: CarSnapshot, carDarkMode: Boolean) {
        this.snapshot = snapshot
        darkMode = snapshot.alwaysDark || carDarkMode
        loadStyleIfNeeded()
    }

    fun release() {
        releaseMap()
        try {
            carContext.getCarService(AppManager::class.java).setSurfaceCallback(null)
        } catch (t: Throwable) {
            Log.w(TAG, "clearing surface callback failed", t)
        }
        onFollowingChanged = null
    }

    // ---- Internals ----

    private var followZoomOverride: Double? = null
    private var pendingOverview: List<GeoPoint>? = null
    private val bitmapCache = HashMap<String, Map<String, Bitmap>>()

    private fun onMapReady(m: MapLibreMap) {
        map = m
        m.uiSettings.apply {
            isRotateGesturesEnabled = false
            isTiltGesturesEnabled = false
            isCompassEnabled = false
            isLogoEnabled = false
        }
        val u = user
        m.moveCamera(
            CameraUpdateFactory.newCameraPosition(
                CameraPosition.Builder()
                    .target(if (u != null) LatLng(u.lat, u.lng) else LatLng(48.0, 10.0))
                    .zoom(if (u != null) 15.0 else 3.0)
                    .build(),
            ),
        )
        styleKey = null
        loadStyleIfNeeded()
    }

    private fun loadStyleIfNeeded() {
        val m = map ?: return
        val json = (if (darkMode) snapshot.darkStyle ?: snapshot.lightStyle else snapshot.lightStyle ?: snapshot.darkStyle)
        val key = "${darkMode}:${json?.hashCode() ?: 0}:${snapshot.iconsVersion}"
        if (key == styleKey) return
        styleKey = key
        style = null
        val gen = generation
        val styleJson = json ?: FallbackStyle.json(darkMode)
        try {
            m.setStyle(Style.Builder().fromJson(styleJson)) { s ->
                if (gen != generation || map !== m) return@setStyle
                style = s
                addImages(s, darkMode)
                pushAll()
                pendingOverview?.let { pendingOverview = null; showOverview(it) }
                if (following) followCamera(animated = false)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "setStyle failed", t)
        }
    }

    private fun addImages(s: Style, dark: Boolean) {
        val cacheKey = "$dark:${snapshot.iconsVersion}"
        val bitmaps = bitmapCache.getOrPut(cacheKey) {
            bitmapCache.clear()
            loadBitmaps(CarStore.iconDir(dark))
        }
        for ((name, bmp) in bitmaps) {
            try {
                s.addImage(name, bmp, false)
            } catch (t: Throwable) {
                Log.w(TAG, "addImage $name failed", t)
            }
        }
    }

    private fun loadBitmaps(dir: File?): Map<String, Bitmap> {
        val files = dir?.listFiles { f -> f.isFile && f.name.endsWith(".png") } ?: return emptyMap()
        val out = HashMap<String, Bitmap>(files.size)
        val opts = BitmapFactory.Options().apply {
            inScaled = false
            inDensity = 0
            inTargetDensity = 0
        }
        for (f in files) {
            val bmp = try {
                BitmapFactory.decodeFile(f.absolutePath, opts)
            } catch (t: Throwable) {
                null
            } ?: continue
            // The phone paints style images at 2x (ThemeIconPainter); MapLibre derives the
            // image pixel ratio from the bitmap density.
            bmp.density = DisplayMetrics.DENSITY_XHIGH
            out[f.name.removeSuffix(".png")] = bmp
        }
        return out
    }

    private fun pushAll() {
        pushUser()
        pushRoute()
        setSource(SRC_PLACES, placesJson)
    }

    private fun pushUser() {
        val u = user
        val json = if (u == null) EMPTY_FC else
            "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[" +
                num(u.lng) + "," + num(u.lat) + "]},\"properties\":{\"bearing\":" + num(userBearing) + "}}]}"
        setSource(SRC_USER, json)
    }

    private fun pushRoute() {
        val line = routeLine
        val routeJson = if (line.size < 2) EMPTY_FC else buildString(line.size * 24 + 96) {
            append("{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\":\"LineString\",\"coordinates\":[")
            line.forEachIndexed { i, p ->
                if (i > 0) append(',')
                append('[').append(num(p.lng)).append(',').append(num(p.lat)).append(']')
            }
            append("]}}]}")
        }
        setSource(SRC_ROUTE, routeJson)
        val d = destination
        val destJson = if (d == null) EMPTY_FC else
            "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[" +
                num(d.lng) + "," + num(d.lat) + "]},\"properties\":{\"name\":" + jsonString(d.name) + "}}]}"
        setSource(SRC_DEST, destJson)
    }

    private fun setSource(id: String, json: String) {
        val s = style ?: return
        try {
            s.getSourceAs<GeoJsonSource>(id)?.setGeoJson(json)
        } catch (t: Throwable) {
            Log.w(TAG, "setGeoJson $id failed", t)
        }
    }

    private fun setFollowing(value: Boolean) {
        if (following == value) return
        following = value
        onFollowingChanged?.invoke(value)
    }

    /** Camera padding [left, top, right, bottom] in px so content sits in the visible area. */
    private fun padding(): DoubleArray {
        val v = visibleArea
        if (v == null || surfaceWidth == 0 || v.isEmpty) return doubleArrayOf(0.0, 0.0, 0.0, 0.0)
        return doubleArrayOf(
            v.left.toDouble(),
            v.top.toDouble(),
            max(0, surfaceWidth - v.right).toDouble(),
            max(0, surfaceHeight - v.bottom).toDouble(),
        )
    }

    private fun visibleCenter(): Point {
        val v = visibleArea
        return if (v != null && !v.isEmpty) Point(v.centerX(), v.centerY()) else Point(surfaceWidth / 2, surfaceHeight / 2)
    }

    private fun followCamera(animated: Boolean) {
        val m = map ?: return
        val u = user ?: return
        val pad = padding()
        if (navigating) {
            // Puck in the lower part of the visible area, heading-up.
            val visibleH = surfaceHeight - pad[1] - pad[3]
            pad[1] += visibleH * 0.4
        }
        val pos = CameraPosition.Builder()
            .target(LatLng(u.lat, u.lng))
            .zoom(followZoomOverride ?: if (navigating) 16.5 else 15.0)
            .tilt(if (navigating) 45.0 else 0.0)
            .bearing(if (navigating) userBearing else 0.0)
            .padding(pad[0], pad[1], pad[2], pad[3])
            .build()
        val update = CameraUpdateFactory.newCameraPosition(pos)
        if (animated) m.easeCamera(update, 900) else m.moveCamera(update)
    }

    private fun releaseMap() {
        generation++
        map = null
        style = null
        styleKey = null
        mapView?.let { mv ->
            try {
                mv.onPause()
                mv.onStop()
                mv.onDestroy()
            } catch (t: Throwable) {
                Log.w(TAG, "MapView teardown", t)
            }
        }
        mapView = null
        try {
            presentation?.dismiss()
        } catch (t: Throwable) {
            Log.w(TAG, "Presentation dismiss", t)
        }
        presentation = null
        try {
            virtualDisplay?.release()
        } catch (t: Throwable) {
            Log.w(TAG, "VirtualDisplay release", t)
        }
        virtualDisplay = null
    }

    companion object {
        private const val TAG = "OverworldCar"
        const val SRC_ROUTE = "app-route"
        const val SRC_PLACES = "app-places"
        const val SRC_USER = "app-user"
        const val SRC_DEST = "app-dest"
        const val EMPTY_FC = "{\"type\":\"FeatureCollection\",\"features\":[]}"

        private fun num(v: Double) = String.format(Locale.US, "%.6f", v)

        fun jsonString(s: String): String {
            val sb = StringBuilder(s.length + 2).append('"')
            for (c in s) {
                when {
                    c == '"' -> sb.append("\\\"")
                    c == '\\' -> sb.append("\\\\")
                    c == '\n' -> sb.append("\\n")
                    c == '\r' -> sb.append("\\r")
                    c == '\t' -> sb.append("\\t")
                    c < ' ' -> sb.append(String.format(Locale.US, "\\u%04x", c.code))
                    else -> sb.append(c)
                }
            }
            return sb.append('"').toString()
        }
    }
}
