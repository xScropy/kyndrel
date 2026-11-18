package dev.kyndrel.kyndrel

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Links (release page, bug report) open in the browser; see
        // lib/core/platform/open_external.dart.
        MethodChannel(messenger, "kyndrel/open_external").setMethodCallHandler { call, result ->
            if (call.method != "open") return@setMethodCallHandler result.notImplemented()
            val target = call.arguments as? String
                ?: return@setMethodCallHandler result.error("args", "a URL is needed", null)
            try {
                startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(target))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(null)
            } catch (e: ActivityNotFoundException) {
                result.error("no_app", "No app can open $target", null)
            }
        }
    }
}
