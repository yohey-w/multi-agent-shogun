package com.shogun.android.viewmodel

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import com.shogun.android.util.Defaults
import com.shogun.android.util.PrefsKeys
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class SettingsViewModel(application: Application) : AndroidViewModel(application) {

    private val prefs = application.getSharedPreferences(PrefsKeys.PREFS_NAME, Context.MODE_PRIVATE)

    private val _notificationEnabled = MutableStateFlow(prefs.getBoolean(PrefsKeys.NOTIFICATION_ENABLED, true))
    val notificationEnabled: StateFlow<Boolean> = _notificationEnabled

    private val _ntfyTopic = MutableStateFlow(prefs.getString(PrefsKeys.NTFY_TOPIC, Defaults.NTFY_TOPIC) ?: Defaults.NTFY_TOPIC)
    val ntfyTopic: StateFlow<String> = _ntfyTopic

    private val _notifyCmdComplete = MutableStateFlow(prefs.getBoolean(PrefsKeys.NOTIFY_CMD_COMPLETE, true))
    val notifyCmdComplete: StateFlow<Boolean> = _notifyCmdComplete

    private val _notifyCmdFailure = MutableStateFlow(prefs.getBoolean(PrefsKeys.NOTIFY_CMD_FAILURE, true))
    val notifyCmdFailure: StateFlow<Boolean> = _notifyCmdFailure

    private val _notifyActionRequired = MutableStateFlow(prefs.getBoolean(PrefsKeys.NOTIFY_ACTION_REQUIRED, true))
    val notifyActionRequired: StateFlow<Boolean> = _notifyActionRequired

    private val _notifyDashboardUpdate = MutableStateFlow(prefs.getBoolean(PrefsKeys.NOTIFY_DASHBOARD_UPDATE, false))
    val notifyDashboardUpdate: StateFlow<Boolean> = _notifyDashboardUpdate

    private val _notifyStreakUpdate = MutableStateFlow(prefs.getBoolean(PrefsKeys.NOTIFY_STREAK_UPDATE, false))
    val notifyStreakUpdate: StateFlow<Boolean> = _notifyStreakUpdate

    private val _notifyAgentResponse = MutableStateFlow(prefs.getBoolean(PrefsKeys.NOTIFY_AGENT_RESPONSE, false))
    val notifyAgentResponse: StateFlow<Boolean> = _notifyAgentResponse

    fun setNotificationEnabled(value: Boolean) {
        _notificationEnabled.value = value
        prefs.edit().putBoolean(PrefsKeys.NOTIFICATION_ENABLED, value).apply()
    }

    fun setNtfyTopic(value: String) {
        _ntfyTopic.value = value
        prefs.edit().putString(PrefsKeys.NTFY_TOPIC, value).apply()
    }

    fun setNotifyCmdComplete(value: Boolean) {
        _notifyCmdComplete.value = value
        prefs.edit().putBoolean(PrefsKeys.NOTIFY_CMD_COMPLETE, value).apply()
    }

    fun setNotifyCmdFailure(value: Boolean) {
        _notifyCmdFailure.value = value
        prefs.edit().putBoolean(PrefsKeys.NOTIFY_CMD_FAILURE, value).apply()
    }

    fun setNotifyActionRequired(value: Boolean) {
        _notifyActionRequired.value = value
        prefs.edit().putBoolean(PrefsKeys.NOTIFY_ACTION_REQUIRED, value).apply()
    }

    fun setNotifyDashboardUpdate(value: Boolean) {
        _notifyDashboardUpdate.value = value
        prefs.edit().putBoolean(PrefsKeys.NOTIFY_DASHBOARD_UPDATE, value).apply()
    }

    fun setNotifyStreakUpdate(value: Boolean) {
        _notifyStreakUpdate.value = value
        prefs.edit().putBoolean(PrefsKeys.NOTIFY_STREAK_UPDATE, value).apply()
    }

    fun setNotifyAgentResponse(value: Boolean) {
        _notifyAgentResponse.value = value
        prefs.edit().putBoolean(PrefsKeys.NOTIFY_AGENT_RESPONSE, value).apply()
    }
}
