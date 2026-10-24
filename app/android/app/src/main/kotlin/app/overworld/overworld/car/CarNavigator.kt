package app.overworld.overworld.car

import android.location.Location
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.navigation.NavigationManager
import androidx.car.app.navigation.NavigationManagerCallback
import androidx.car.app.navigation.model.Destination
import androidx.car.app.navigation.model.Step
import androidx.car.app.navigation.model.Trip
import app.overworld.overworld.R
import java.util.concurrent.Future

/**
 * Active guidance for the car session: progress tracking, rerouting, voice
 * cues, map overlays, [NavigationManager] lifecycle and the location
 * foreground service.
 */
class CarNavigator(
    private val carContext: CarContext,
    private val ui: CarUi,
    private val services: CarServices,
    private val location: LocationTracker,
    private val renderer: MapSurfaceRenderer,
    private val voice: CarVoice,
) : LocationTracker.Listener {

    /** Called (main thread) whenever guidance state changes and the template should refresh. */
    var onChanged: (() -> Unit)? = null

    var destination: CarPlace? = null
        private set
    var route: Route? = null
        private set
    var progress: NavProgress? = null
        private set
    var rerouting = false
        private set
    var arrived = false
        private set

    val active: Boolean get() = route != null

    private var tracker: ProgressTracker? = null
    private var rerouteCall: Future<*>? = null
    private var lastRerouteAt = 0L
    private var lastFix: Fix? = null
    private var lastBearing = 0.0
    private val main = Handler(Looper.getMainLooper())
    private val navManager: NavigationManager = carContext.getCarService(NavigationManager::class.java)
    private var navStartedWithHost = false

    init {
        navManager.setNavigationManagerCallback(object : NavigationManagerCallback {
            override fun onStopNavigation() {
                // The host asked us to stop (e.g. another nav app started).
                stop(fromHost = true)
            }

            override fun onAutoDriveEnabled() {
                Log.i(TAG, "auto drive requested; not supported (uses real location)")
            }
        })
        location.addListener(this)
    }

    /** Starts guidance along [r] to [dest]. Caller has already checked the Pro entitlement. */
    fun start(r: Route, dest: CarPlace) {
        stopInternal(clearMap = false)
        destination = dest
        route = r
        tracker = ProgressTracker(r)
        arrived = false
        rerouting = false
        try {
            navManager.navigationStarted()
            navStartedWithHost = true
        } catch (t: Throwable) {
            Log.w(TAG, "navigationStarted failed", t)
        }
        NavigationForegroundService.start(carContext, dest.name)
        renderer.setRoute(r.geometry, dest)
        renderer.navigating = true
        renderer.recenter()
        location.start()
        // Feed the latest fix immediately so the first instruction shows (and is spoken) at once.
        lastFix?.let { handleFix(it, it.speedMps) }
        onChanged?.invoke()
    }

    /** Ends guidance (End button, arrival timeout, or host request). */
    fun stop(fromHost: Boolean = false) {
        if (!active) return
        if (fromHost) Log.i(TAG, "navigation stopped by host")
        stopInternal(clearMap = true)
        onChanged?.invoke()
    }

    private fun stopInternal(clearMap: Boolean) {
        rerouteCall?.cancel(true)
        rerouteCall = null
        main.removeCallbacksAndMessages(null)
        val wasActive = route != null
        route = null
        tracker = null
        progress = null
        destination = null
        rerouting = false
        arrived = false
        if (wasActive) {
            voice.stop()
            NavigationForegroundService.stop(carContext)
        }
        if (navStartedWithHost) {
            // Idempotent; also required after the host's onStopNavigation.
            navStartedWithHost = false
            try {
                navManager.navigationEnded()
            } catch (t: Throwable) {
                Log.w(TAG, "navigationEnded failed", t)
            }
        }
        if (clearMap) {
            renderer.clearRoute()
            renderer.navigating = false
        }
    }

    override fun onFix(fix: Fix, raw: Location) {
        lastFix = fix
        handleFix(fix, fix.speedMps)
    }

    private fun handleFix(fix: Fix, speedMps: Double) {
        val t = tracker
        if (t == null || arrived) {
            if (fix.headingDeg != null && fix.speedMps > 1.5) lastBearing = fix.headingDeg
            renderer.updateUser(fix.position, lastBearing)
            return
        }
        val p = t.update(fix)
        progress = p
        lastBearing = p.bearingDeg
        renderer.updateUser(p.snapped, p.bearingDeg)

        for (cue in t.cuesFor(p, speedMps)) {
            voice.speak(Phrases.phraseFor(cue, ui.imperial, CarStore.snapshot.locale))
        }
        if (p.arrived) {
            onArrived()
        } else if (p.offRoute) {
            maybeReroute(fix)
        }
        updateTrip(p)
        onChanged?.invoke()
    }

    private fun onArrived() {
        if (arrived) return
        arrived = true
        // Release the host's navigation state right away; keep the arrival card a moment.
        if (navStartedWithHost) {
            navStartedWithHost = false
            try {
                navManager.navigationEnded()
            } catch (t: Throwable) {
                Log.w(TAG, "navigationEnded failed", t)
            }
        }
        NavigationForegroundService.stop(carContext)
        main.postDelayed({ stop() }, ARRIVAL_CARD_MS)
    }

    private fun maybeReroute(fix: Fix) {
        val dest = destination ?: return
        val now = SystemClock.elapsedRealtime()
        if (rerouting || now - lastRerouteAt < REROUTE_COOLDOWN_MS) return
        rerouting = true
        lastRerouteAt = now
        voice.speak(Phrases.reroute(CarStore.snapshot.locale))
        onChanged?.invoke()
        rerouteCall = services.route(fix.position, dest.point, fix.headingDeg?.takeIf { fix.speedMps > 3 }) { result ->
            rerouteCall = null
            if (destination !== dest) return@route
            rerouting = false
            result.onSuccess { r ->
                route = r
                tracker = ProgressTracker(r)
                renderer.setRoute(r.geometry, dest)
                lastFix?.let { handleFix(it, it.speedMps) }
            }.onFailure {
                safeToast(ui.s(R.string.car_route_error))
            }
            onChanged?.invoke()
        }
    }

    private fun updateTrip(p: NavProgress) {
        val dest = destination ?: return
        val next = p.nextStep ?: return
        if (!navStartedWithHost) return
        try {
            val estimate = ui.travelEstimate(p.remainingM, p.remainingS)
            val stepEstimate = ui.travelEstimate(p.distanceToNextM, 0.0)
            val trip = Trip.Builder()
                .addStep(carStep(next), stepEstimate)
                .addDestination(Destination.Builder().setName(dest.name).apply { dest.address?.let { setAddress(it) } }.build(), estimate)
            route?.steps?.getOrNull(p.currentStepIndex)?.streetName?.takeIf { it.isNotBlank() }?.let { trip.setCurrentRoad(it) }
            navManager.updateTrip(trip.build())
        } catch (t: Throwable) {
            Log.w(TAG, "updateTrip failed", t)
        }
    }

    fun carStep(s: RouteStep): Step {
        val b = Step.Builder(ui.cue(s)).setManeuver(ui.maneuver(s))
        if (s.streetName.isNotEmpty()) b.setRoad(s.streetName)
        return b.build()
    }

    private fun safeToast(text: String) {
        try {
            CarToast.makeText(carContext, text, CarToast.LENGTH_LONG).show()
        } catch (t: Throwable) {
            Log.w(TAG, "toast failed", t)
        }
    }

    fun release() {
        location.removeListener(this)
        stopInternal(clearMap = false)
        try {
            navManager.clearNavigationManagerCallback()
        } catch (t: Throwable) {
            Log.w(TAG, "clearNavigationManagerCallback failed", t)
        }
        onChanged = null
    }

    companion object {
        private const val TAG = "OverworldCar"
        private const val REROUTE_COOLDOWN_MS = 10_000L
        private const val ARRIVAL_CARD_MS = 12_000L
    }
}
