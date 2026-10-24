package app.overworld.overworld.car

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import app.overworld.overworld.R

/**
 * Foreground service (type `location`) kept alive while car navigation is
 * active, so guidance and location updates continue when the driver switches
 * to another app on the car screen (e.g. media). It does no work itself; the
 * car session owns location/progress. Started from the car session while the
 * car app is in the foreground on the car screen, which Android Auto treats as
 * a foreground context.
 */
class NavigationForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            val n = buildNotification(this, intent?.getStringExtra(EXTRA_TEXT))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } else {
                startForeground(NOTIFICATION_ID, n)
            }
        } catch (t: Throwable) {
            // E.g. ForegroundServiceStartNotAllowedException / missing location permission.
            Log.w(TAG, "could not enter foreground", t)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    companion object {
        private const val TAG = "OverworldCar"
        private const val CHANNEL_ID = "overworld_car_navigation"
        private const val NOTIFICATION_ID = 0x0C42
        private const val ACTION_STOP = "app.overworld.overworld.car.STOP_NAV"
        private const val EXTRA_TEXT = "text"

        fun start(context: Context, text: String?) {
            // A location-type foreground service needs location permission; without it
            // startForeground() would throw after the service was already started.
            val granted = context.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED ||
                context.checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
            if (!granted) return
            val i = Intent(context, NavigationForegroundService::class.java).putExtra(EXTRA_TEXT, text)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(i) else context.startService(i)
            } catch (t: Throwable) {
                Log.w(TAG, "navigation foreground service not started", t)
            }
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, NavigationForegroundService::class.java))
            } catch (t: Throwable) {
                Log.w(TAG, "navigation foreground service stop", t)
            }
        }

        private fun buildNotification(context: Context, text: String?): Notification {
            val title = context.getString(R.string.car_nav_notification_title)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = context.getSystemService(NotificationManager::class.java)
                if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                    nm.createNotificationChannel(
                        NotificationChannel(CHANNEL_ID, context.getString(R.string.car_nav_channel), NotificationManager.IMPORTANCE_LOW),
                    )
                }
                return Notification.Builder(context, CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_car_navigation)
                    .setContentTitle(title)
                    .setContentText(text ?: "")
                    .setOngoing(true)
                    .setCategory(Notification.CATEGORY_NAVIGATION)
                    .build()
            }
            @Suppress("DEPRECATION")
            return Notification.Builder(context)
                .setSmallIcon(R.drawable.ic_car_navigation)
                .setContentTitle(title)
                .setContentText(text ?: "")
                .setOngoing(true)
                .setPriority(Notification.PRIORITY_LOW)
                .build()
        }
    }
}
