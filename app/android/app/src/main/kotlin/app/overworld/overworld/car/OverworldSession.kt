package app.overworld.overworld.car

import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.util.Log
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.ScreenManager
import androidx.car.app.Session
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import app.overworld.overworld.car.screens.MainNavScreen
import app.overworld.overworld.car.screens.PermissionScreen
import app.overworld.overworld.car.screens.ProGateScreen
import app.overworld.overworld.car.screens.RoutePreviewScreen
import app.overworld.overworld.car.screens.SearchScreen

/**
 * One Android Auto session. Owns the map renderer, location, voice, network
 * services and the navigator; screens reach them through this object.
 */
class OverworldSession : Session() {
    lateinit var ui: CarUi
        private set
    lateinit var services: CarServices
        private set
    lateinit var location: LocationTracker
        private set
    lateinit var voice: CarVoice
        private set
    lateinit var renderer: MapSurfaceRenderer
        private set
    lateinit var navigator: CarNavigator
        private set

    private var initialized = false
    private var mainScreen: MainNavScreen? = null

    private val storeListener = CarStore.Listener { snap -> applySnapshot(snap) }

    val screenManager: ScreenManager get() = carContext.getCarService(ScreenManager::class.java)

    private fun setUp() {
        if (initialized) return
        initialized = true
        CarStore.init(carContext)
        ui = CarUi(carContext)
        services = CarServices()
        location = LocationTracker(carContext)
        voice = CarVoice(carContext)
        renderer = MapSurfaceRenderer(carContext)
        renderer.attach()
        navigator = CarNavigator(carContext, ui, services, location, renderer, voice)
        applySnapshot(CarStore.snapshot)
        CarStore.addListener(storeListener)
        CarStore.previewListener = CarStore.PreviewListener { place -> openDestination(place) }

        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                location.start()
            }

            override fun onStop(owner: LifecycleOwner) {
                // Keep location running while guiding (the foreground service keeps us alive).
                if (!navigator.active) location.stop()
            }

            override fun onDestroy(owner: LifecycleOwner) {
                release()
            }
        })
    }

    override fun onCreateScreen(intent: Intent): Screen {
        setUp()
        val main = MainNavScreen(carContext, this)
        mainScreen = main
        if (!location.hasPermission()) {
            screenManager.push(main)
            return PermissionScreen(carContext, this)
        }
        // A route preview sent from the phone while no car session was connected.
        val pending = CarStore.takePendingPreview()
        if (pending != null) {
            screenManager.push(main)
            return destinationScreen(pending)
        }
        val fromIntent = navigateIntentTarget(intent) ?: return main
        screenManager.push(main)
        val place = fromIntent.place
        return if (place != null) destinationScreen(place) else SearchScreen(carContext, this, initialQuery = fromIntent.query)
    }

    override fun onNewIntent(intent: Intent) {
        if (!initialized) return
        val target = navigateIntentTarget(intent) ?: return
        val place = target.place
        if (place != null) openDestination(place) else screenManager.push(SearchScreen(carContext, this, initialQuery = target.query))
    }

    override fun onCarConfigurationChanged(newConfiguration: Configuration) {
        if (!initialized) return
        renderer.applyTheme(CarStore.snapshot, carContext.isDarkMode)
    }

    /** Shows the route preview for [place], or the Pro gate when not entitled. */
    fun openDestination(place: CarPlace) {
        if (!initialized || lifecycle.currentState == Lifecycle.State.DESTROYED) return
        try {
            screenManager.push(destinationScreen(place))
        } catch (t: Throwable) {
            Log.w(TAG, "could not open destination", t)
        }
    }

    private fun destinationScreen(place: CarPlace): Screen =
        if (CarStore.snapshot.premium) RoutePreviewScreen(carContext, this, place) else ProGateScreen(carContext, this)

    /** Called by the preview when the driver taps Go. */
    fun startNavigation(route: Route, place: CarPlace) {
        if (!CarStore.snapshot.premium) {
            screenManager.push(ProGateScreen(carContext, this))
            return
        }
        screenManager.popToRoot()
        navigator.start(route, place)
    }

    /** Restores the map overlays after a cancelled preview. */
    fun restoreMap() {
        val r = navigator.route
        val d = navigator.destination
        if (r != null && d != null) renderer.setRoute(r.geometry, d) else renderer.clearRoute()
        renderer.recenter()
    }

    private fun applySnapshot(snap: CarSnapshot) {
        voice.configure(snap.voice, snap.locale, snap.muted)
        renderer.applyTheme(snap, carContext.isDarkMode)
        renderer.setPlaces(snap.places)
        try {
            screenManager.top.invalidate()
        } catch (t: Throwable) {
            // No screen yet.
        }
    }

    private fun release() {
        CarStore.removeListener(storeListener)
        if (CarStore.previewListener != null) CarStore.previewListener = null
        try {
            navigator.release()
        } catch (t: Throwable) {
            Log.w(TAG, "navigator release", t)
        }
        location.stop()
        voice.release()
        renderer.release()
        services.shutdown()
        mainScreen = null
    }

    private class NavigateTarget(val place: CarPlace?, val query: String?)

    /** Handles [CarContext.ACTION_NAVIGATE] (`geo:lat,lng`, `geo:0,0?q=lat,lng(label)` or `geo:0,0?q=address`). */
    private fun navigateIntentTarget(intent: Intent?): NavigateTarget? {
        if (intent?.action != CarContext.ACTION_NAVIGATE) return null
        val uri: Uri = intent.data ?: return null
        if (uri.scheme != "geo") return null
        val ssp = uri.schemeSpecificPart ?: return null
        val coordPart = ssp.substringBefore('?')
        val q = if (ssp.contains("?")) Uri.parse("geo:0,0?" + ssp.substringAfter('?')).getQueryParameter("q") else null
        fun parseLatLng(s: String): Pair<Double, Double>? {
            val parts = s.substringBefore(';').split(',')
            if (parts.size < 2) return null
            val lat = parts[0].trim().toDoubleOrNull() ?: return null
            val lng = parts[1].trim().toDoubleOrNull() ?: return null
            if (lat == 0.0 && lng == 0.0) return null
            return lat to lng
        }
        if (!q.isNullOrBlank()) {
            val label = q.substringAfter('(', "").substringBefore(')').ifBlank { null }
            parseLatLng(q.substringBefore('('))?.let { (lat, lng) ->
                return NavigateTarget(CarPlace(label ?: "%.5f, %.5f".format(java.util.Locale.US, lat, lng), lat, lng), null)
            }
            return NavigateTarget(null, q)
        }
        parseLatLng(coordPart)?.let { (lat, lng) ->
            return NavigateTarget(CarPlace("%.5f, %.5f".format(java.util.Locale.US, lat, lng), lat, lng), null)
        }
        return null
    }

    companion object {
        private const val TAG = "OverworldCar"
    }
}
