package com.shogun.android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import com.shogun.android.util.Defaults
import com.shogun.android.util.PrefsKeys
import java.util.concurrent.TimeUnit

class NtfyService : Service() {

    private val client = OkHttpClient.Builder()
        .pingInterval(30, TimeUnit.SECONDS)
        .build()

    private var webSocket: WebSocket? = null
    private var lastReceivedId: String = ""
    private var backoffIndex = 0
    private val reconnectHandler = Handler(Looper.getMainLooper())
    private var reconnectRunnable: Runnable? = null
    private lateinit var connectivityManager: ConnectivityManager
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    companion object {
        private const val CHANNEL_ID = "ntfy_service"
        private const val NOTIFICATION_ID = 2
        private val TOPIC = Defaults.NTFY_TOPIC
        private val BACKOFF_DELAYS = longArrayOf(5_000L, 10_000L, 30_000L, 60_000L)
    }

    override fun onCreate() {
        super.onCreate()
        val prefs = getSharedPreferences(PrefsKeys.PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(PrefsKeys.NOTIFICATION_ENABLED, true)) {
            stopSelf()
            return
        }
        createForegroundChannel()
        startForeground(NOTIFICATION_ID, buildForegroundNotification())
        connectivityManager = getSystemService(ConnectivityManager::class.java)
        registerNetworkCallback()
        connect()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onBind(intent: Intent): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        reconnectRunnable?.let { reconnectHandler.removeCallbacks(it) }
        networkCallback?.let { connectivityManager.unregisterNetworkCallback(it) }
        webSocket?.cancel()
        client.dispatcher.executorService.shutdown()
    }

    private fun connect() {
        val since = if (lastReceivedId.isNotEmpty()) "?since=$lastReceivedId" else "?since=30m"
        val url = "wss://ntfy.sh/$TOPIC/ws$since"
        val request = Request.Builder().url(url).build()
        webSocket = client.newWebSocket(request, NtfyWebSocketListener())
    }

    private fun scheduleReconnect() {
        reconnectRunnable?.let { reconnectHandler.removeCallbacks(it) }
        val delay = BACKOFF_DELAYS.getOrElse(backoffIndex) { BACKOFF_DELAYS.last() }
        if (backoffIndex < BACKOFF_DELAYS.size - 1) backoffIndex++
        reconnectRunnable = Runnable { connect() }.also {
            reconnectHandler.postDelayed(it, delay)
        }
    }

    private fun registerNetworkCallback() {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                reconnectRunnable?.let { reconnectHandler.removeCallbacks(it) }
                webSocket?.cancel()
                backoffIndex = 0
                connect()
            }
        }
        connectivityManager.registerNetworkCallback(request, networkCallback!!)
    }

    private fun createForegroundChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "ntfy接続",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "プッシュ通知の受信を維持します"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildForegroundNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("将軍通知")
            .setContentText("ntfy受信中...")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    inner class NtfyWebSocketListener : WebSocketListener() {
        override fun onMessage(webSocket: WebSocket, text: String) {
            try {
                val json = JSONObject(text)
                if (json.optString("event") != "message") return

                lastReceivedId = json.optString("id", lastReceivedId)
                backoffIndex = 0

                val title = json.optString("title", "")
                val message = json.optString("message", "")
                val tagsArray = json.optJSONArray("tags")
                val tags = buildList {
                    if (tagsArray != null) {
                        for (i in 0 until tagsArray.length()) add(tagsArray.getString(i))
                    }
                }
                NotificationHelper.showNotification(this@NtfyService, message, tags, title)
            } catch (_: Exception) {
                // Malformed JSON — ignore
            }
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            scheduleReconnect()
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            scheduleReconnect()
        }
    }
}
