package app.overworld.overworld

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import app.overworld.overworld.car.CarStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var shareChannel: MethodChannel? = null

    /// Text shared to the app before Flutter asked for it (cold start).
    private var pendingShare: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        pendingShare = sharedText(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = sharedText(intent) ?: return
        val channel = shareChannel
        if (channel != null) channel.invokeMethod("shared", text) else pendingShare = text
    }

    /// "Share" from another app (e.g. Google Maps): subject + text, which
    /// usually holds the place name and a maps.app.goo.gl link.
    private fun sharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("text/") != true) return null
        val parts = listOfNotNull(
            intent.getStringExtra(Intent.EXTRA_SUBJECT),
            intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString(),
        ).filter { it.isNotBlank() }
        return parts.joinToString("\n").ifBlank { null }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "overworld/share").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "initial" -> {
                        result.success(pendingShare)
                        pendingShare = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        // Phone → Android Auto bridge (see lib/car/car_bridge.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "overworld/car").setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *>
            when (call.method) {
                "sync" -> {
                    if (args == null) {
                        result.error("bad_args", "sync expects a map", null)
                    } else {
                        CarStore.sync(applicationContext, args) { error ->
                            if (error == null) result.success(null) else result.error("sync_failed", error.message, null)
                        }
                    }
                }
                "previewRoute" -> {
                    if (args != null) {
                        CarStore.init(applicationContext)
                        CarStore.requestPreview(args)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "overworld/system").setMethodCallHandler { call, result ->
            when (call.method) {
                // Android 12+: unverified domains (openstreetmap.org, Google/Apple
                // Maps) open in the browser unless the user allows them here.
                "openLinkSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        Intent(Settings.ACTION_APP_OPEN_BY_DEFAULT_SETTINGS, Uri.parse("package:$packageName"))
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    }
                    try {
                        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
