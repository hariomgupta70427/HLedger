package com.hariverse.hledger.detection

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * The only way Dart talks to the capture layer.
 *
 * The event channel carries a bare signal, not the payload: the disk queue stays
 * the single record of what was captured, so a notification that arrives while
 * the UI is alive and one that arrives while it is dead travel exactly the same
 * path. That is what makes the live case impossible to get subtly wrong.
 */
object CaptureBridge {
    private const val METHOD_CHANNEL = "hledger/notification_capture"
    private const val EVENT_CHANNEL = "hledger/notification_capture/events"
    private const val TAG = "HLedgerCapture"

    private var events: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> result.success(isGranted(context))
                    "openPermissionSettings" -> {
                        openSettings(context)
                        result.success(null)
                    }
                    "drain" -> result.success(CaptureStore.drain(context))
                    "acknowledge" -> {
                        val keys = call.argument<List<String>>("keys").orEmpty()
                        CaptureStore.acknowledge(context, keys.toSet())
                        result.success(null)
                    }
                    "skippedSources" -> result.success(CaptureStore.skipped(context))
                    "clearSkippedSources" -> {
                        CaptureStore.clearSkipped(context)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                }

                override fun onCancel(arguments: Any?) {
                    events = null
                }
            })
    }

    /** Tells Dart the queue grew. A no-op when nothing is listening. */
    fun notifyCaptured() {
        val sink = events ?: return
        mainHandler.post {
            try {
                sink.success(true)
            } catch (e: Exception) {
                Log.w(TAG, "Could not signal Dart", e)
            }
        }
    }

    fun isGranted(context: Context): Boolean = try {
        NotificationManagerCompat.getEnabledListenerPackages(context)
            .contains(context.packageName)
    } catch (e: Exception) {
        Log.e(TAG, "Permission check failed", e)
        false
    }

    /**
     * Notification access cannot be granted by a dialog — only the user can turn
     * it on in Settings. On API 30+ Android can open this app's own entry
     * directly, which is a far shorter path than a list of every installed app.
     */
    private fun openSettings(context: Context) {
        val component = ComponentName(context, NotificationCaptureService::class.java)
        val intents = mutableListOf<Intent>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            intents.add(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    component.flattenToString(),
                )
            )
        }
        intents.add(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))

        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(intent)
                return
            } catch (e: Exception) {
                Log.w(TAG, "Could not open ${intent.action}", e)
            }
        }
        Log.e(TAG, "No notification-access settings screen available")
    }
}
