package dev.inkora.inkora

import android.os.Build
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var immersiveReading = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "inkora/download_background")
            .setMethodCallHandler { call, result ->
                try {
                    DownloadBackground.initialize(this)
                    when (call.method) {
                        "foreground" -> {
                            val thread = DownloadBackground.worker?.thread
                            DownloadBackground.pause()
                            Thread {
                                thread?.join(20_000)
                                val stillRunning = thread?.isAlive == true
                                if (!stillRunning) DownloadBackground.resetInterrupted()
                                runOnUiThread {
                                    if (stillRunning) result.error("busy", "Background transfer is stopping.", null)
                                    else result.success(null)
                                }
                            }.start()
                        }
                        "enqueue" -> {
                            val arguments = call.arguments as Map<*, *>
                            @Suppress("UNCHECKED_CAST")
                            DownloadBackground.enqueue(arguments["tasks"] as List<Map<String, Any?>>, arguments["headers"] as Map<String, String>, arguments["wifiOnly"] as Boolean)
                            result.success(null)
                        }
                        "results" -> result.success(DownloadBackground.results())
                        "accounts" -> result.success(DownloadBackground.accounts())
                        "excludeFromBackup" -> result.success(null) // App backup is disabled in the manifest.
                        "acknowledge" -> { DownloadBackground.remove(call.arguments as String); result.success(null) }
                        "cancelAccount" -> { DownloadBackground.cancelAccount(call.arguments as String); result.success(null) }
                        "status" -> result.success(DownloadBackground.status())
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) { result.error("background_transfer", "Native transfer unavailable.", null) }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "inkora/reader_network_policy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "current" -> result.success(readerNetworkPolicy(this))
                    // Dart subscribes to push events only when they exist.
                    "events" -> result.success(true)
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "inkora/reader_network_policy/events")
            .setStreamHandler(NetworkPolicyEvents(applicationContext))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "inkora/reader_system_ui")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setImmersive" -> {
                        val immersive = call.arguments as? Boolean
                        if (immersive == null) {
                            result.error("invalid_argument", "Expected an immersive boolean.", null)
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            immersiveReading = immersive
                            applyReaderSystemUi()
                            result.success(true)
                        } else {
                            // Dart uses Flutter's legacy immersive implementation below API 30.
                            result.success(false)
                        }
                    }
                    "systemBarsHidden" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val insets = window.decorView.rootWindowInsets
                            result.success(insets != null &&
                                !insets.isVisible(WindowInsets.Type.statusBars()) &&
                                !insets.isVisible(WindowInsets.Type.navigationBars()))
                        } else {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        DownloadBackground.pause()
    }

    override fun onStop() {
        super.onStop()
        DownloadBackground.foreground = false
        try { DownloadBackground.initialize(this); DownloadBackground.schedule() } catch (_: Exception) { /* Retry when app opens. */ }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) applyReaderSystemUi()
    }

    private fun applyReaderSystemUi() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                if (immersiveReading) {
                    controller.hide(WindowInsets.Type.systemBars())
                } else {
                    controller.show(WindowInsets.Type.systemBars())
                }
            }
        }
    }
}
