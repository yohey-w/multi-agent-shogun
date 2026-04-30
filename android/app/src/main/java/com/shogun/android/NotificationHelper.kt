package com.shogun.android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.shogun.android.util.PrefsKeys

object NotificationHelper {

    private const val CH_CMD_COMPLETE = "cmd_complete"
    private const val CH_CMD_FAILURE = "cmd_failure"
    private const val CH_ACTION_REQUIRED = "action_required"
    private const val CH_DASHBOARD_UPDATE = "dashboard_update"
    private const val CH_STREAK_UPDATE = "streak_update"
    private const val CH_AGENT_RESPONSE = "agent_response"

    fun initChannels(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        val channels = listOf(
            NotificationChannel(CH_CMD_COMPLETE, "タスク完了", NotificationManager.IMPORTANCE_DEFAULT).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 200)
            },
            NotificationChannel(CH_CMD_FAILURE, "タスク失敗", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 100, 300)
            },
            NotificationChannel(CH_ACTION_REQUIRED, "要対応", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 100, 300)
            },
            NotificationChannel(CH_DASHBOARD_UPDATE, "ダッシュボード", NotificationManager.IMPORTANCE_LOW).apply {
                enableVibration(false)
            },
            NotificationChannel(CH_STREAK_UPDATE, "ストリーク", NotificationManager.IMPORTANCE_LOW).apply {
                enableVibration(false)
            },
            NotificationChannel(CH_AGENT_RESPONSE, "エージェント", NotificationManager.IMPORTANCE_LOW).apply {
                enableVibration(false)
            },
        )
        nm.createNotificationChannels(channels)
    }

    fun showNotification(context: Context, message: String, tags: List<String>, title: String) {
        val prefs = context.getSharedPreferences(PrefsKeys.PREFS_NAME, Context.MODE_PRIVATE)

        val channelId: String
        val prefKey: String
        when {
            tags.any { it.contains("cmd_complete") } -> {
                channelId = CH_CMD_COMPLETE
                prefKey = "notify_cmd_complete"
            }
            tags.any { it.contains("failure") } -> {
                channelId = CH_CMD_FAILURE
                prefKey = "notify_cmd_failure"
            }
            tags.any { it.contains("action_required") } -> {
                channelId = CH_ACTION_REQUIRED
                prefKey = "notify_action_required"
            }
            tags.any { it.contains("dashboard") } -> {
                channelId = CH_DASHBOARD_UPDATE
                prefKey = "notify_dashboard_update"
            }
            tags.any { it.contains("streak") } -> {
                channelId = CH_STREAK_UPDATE
                prefKey = "notify_streak_update"
            }
            tags.any { it.contains("agent") } -> {
                channelId = CH_AGENT_RESPONSE
                prefKey = "notify_agent_response"
            }
            else -> {
                channelId = CH_CMD_COMPLETE
                prefKey = "notify_cmd_complete"
            }
        }

        if (!prefs.getBoolean(prefKey, true)) return

        val pendingIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = Notification.Builder(context, channelId)
            .setContentTitle(title.ifBlank { "将軍通知" })
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val nm = context.getSystemService(NotificationManager::class.java)
        nm.notify(System.currentTimeMillis().toInt(), notification)
    }
}
