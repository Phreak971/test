package app.overworld.overworld

import app.overworld.overworld.car.CarStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
    }
}
