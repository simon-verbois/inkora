package dev.inkora.inkora

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/** Cost/Data Saver snapshot shared by the polling method and the event stream. */
fun readerNetworkPolicy(context: Context): Map<String, Boolean> {
    val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val dataSaver = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
        connectivity.restrictBackgroundStatus == ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED
    return mapOf("metered" to connectivity.isActiveNetworkMetered, "dataSaver" to dataSaver)
}

/**
 * Pushes policy changes instead of Dart polling every five seconds: the
 * default-network callback covers Wi-Fi/cellular/metered/offline transitions
 * and the restrict-background broadcast covers Data Saver toggles. Duplicate
 * snapshots are suppressed; delivery happens on the main thread.
 */
class NetworkPolicyEvents(private val context: Context) : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var last: Map<String, Boolean>? = null
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var receiver: BroadcastReceiver? = null

    private fun publish() {
        main.post {
            val events = sink ?: return@post
            val policy = readerNetworkPolicy(context)
            if (policy != last) {
                last = policy
                events.success(policy)
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        last = null
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) = publish()
                override fun onLost(network: Network) = publish()
                override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) = publish()
            }
            connectivity.registerDefaultNetworkCallback(networkCallback)
            callback = networkCallback
            val dataSaverReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) = publish()
            }
            val filter = IntentFilter(ConnectivityManager.ACTION_RESTRICT_BACKGROUND_CHANGED)
            // System broadcasts still reach non-exported receivers (API 33+ flag).
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(dataSaverReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(dataSaverReceiver, filter)
            }
            receiver = dataSaverReceiver
        }
        publish()
    }

    override fun onCancel(arguments: Any?) {
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        callback?.let { runCatching { connectivity.unregisterNetworkCallback(it) } }
        receiver?.let { runCatching { context.unregisterReceiver(it) } }
        callback = null
        receiver = null
        sink = null
        last = null
    }
}
