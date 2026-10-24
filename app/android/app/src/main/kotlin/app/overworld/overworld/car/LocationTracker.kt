package app.overworld.overworld.car

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.os.SystemClock
import android.util.Log

/**
 * Location via the platform [LocationManager] (Play Services' fused client is
 * not on the app classpath). Uses the platform "fused" provider on API 31+,
 * otherwise GPS with network as a coarse fallback until GPS has a fix.
 */
class LocationTracker(context: Context) {
    fun interface Listener {
        fun onFix(fix: Fix, raw: Location)
    }

    private val appContext = context.applicationContext
    private val lm = appContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val listeners = LinkedHashSet<Listener>()
    private var running = false
    private var lastGpsAt = 0L

    var last: Location? = null
        private set

    val lastPoint: GeoPoint? get() = last?.let { GeoPoint(it.latitude, it.longitude) }

    private val platformListener = object : LocationListener {
        override fun onLocationChanged(location: Location) = deliver(location)

        // Required on API < 30 where these are abstract.
        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
    }

    fun hasPermission(): Boolean =
        appContext.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            appContext.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    fun addListener(l: Listener) {
        listeners.add(l)
    }

    fun removeListener(l: Listener) {
        listeners.remove(l)
    }

    /** Starts updates (idempotent). Returns false when permission is missing. */
    @SuppressLint("MissingPermission")
    fun start(): Boolean {
        if (running) return true
        if (!hasPermission()) return false
        try {
            val providers = lm.allProviders
            val useFused = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && providers.contains(LocationManager.FUSED_PROVIDER)
            if (useFused) {
                lm.requestLocationUpdates(LocationManager.FUSED_PROVIDER, 1000L, 0f, platformListener, Looper.getMainLooper())
            } else {
                if (providers.contains(LocationManager.GPS_PROVIDER)) {
                    lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, platformListener, Looper.getMainLooper())
                }
                if (providers.contains(LocationManager.NETWORK_PROVIDER)) {
                    lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 3000L, 0f, platformListener, Looper.getMainLooper())
                }
            }
            running = true
            // Seed with the freshest last-known fix so the map can center immediately.
            val seed = providers.mapNotNull { p -> runCatching { lm.getLastKnownLocation(p) }.getOrNull() }
                .maxByOrNull { it.elapsedRealtimeNanos }
            if (seed != null && last == null) deliver(seed)
        } catch (t: SecurityException) {
            Log.w(TAG, "location permission revoked", t)
            return false
        } catch (t: Throwable) {
            Log.w(TAG, "location start failed", t)
            return false
        }
        return true
    }

    fun stop() {
        if (!running) return
        running = false
        try {
            lm.removeUpdates(platformListener)
        } catch (t: Throwable) {
            Log.w(TAG, "location stop failed", t)
        }
    }

    private fun deliver(location: Location) {
        val now = SystemClock.elapsedRealtime()
        if (location.provider == LocationManager.GPS_PROVIDER) {
            lastGpsAt = now
        } else if (location.provider == LocationManager.NETWORK_PROVIDER && now - lastGpsAt < 10_000) {
            return // Prefer recent GPS fixes over coarse network ones.
        }
        last = location
        val fix = Fix(
            position = GeoPoint(location.latitude, location.longitude),
            headingDeg = if (location.hasBearing()) location.bearing.toDouble() else null,
            speedMps = if (location.hasSpeed()) location.speed.toDouble() else 0.0,
            accuracyM = if (location.hasAccuracy()) location.accuracy.toDouble() else 10.0,
        )
        for (l in listeners.toList()) {
            try {
                l.onFix(fix, location)
            } catch (t: Throwable) {
                Log.w(TAG, "location listener failed", t)
            }
        }
    }

    companion object {
        private const val TAG = "OverworldCar"
    }
}
