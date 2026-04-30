package com.shogun.android.viewmodel

import android.app.Application
import android.content.Context
import android.content.Intent
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.shogun.android.SshForegroundService
import com.shogun.android.ssh.SshManager
import com.shogun.android.util.Defaults
import com.shogun.android.util.PrefsKeys
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class ShogunViewModel(application: Application) : AndroidViewModel(application) {

    private val sshManager = SshManager.getInstance()
    private val prefs = application.getSharedPreferences(PrefsKeys.PREFS_NAME, Context.MODE_PRIVATE)

    private val _paneContent = MutableStateFlow("")
    val paneContent: StateFlow<String> = _paneContent

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    private var refreshJob: Job? = null
    private var reconnectJob: Job? = null
    @Volatile private var paused = false

    private fun tmuxTarget(): String {
        val session = prefs.getString(PrefsKeys.SHOGUN_SESSION, Defaults.SHOGUN_SESSION) ?: Defaults.SHOGUN_SESSION
        return "$session:main"
    }

    fun pauseRefresh() { paused = true }
    fun resumeRefresh() {
        paused = false
        viewModelScope.launch {
            if (sshManager.isConnected()) {
                val result = sshManager.execCommand("${Defaults.TMUX} capture-pane -t ${tmuxTarget()} -p -e -S -500")
                if (result.isSuccess) {
                    _paneContent.value = result.getOrDefault("")
                    _errorMessage.value = null
                }
            }
        }
    }

    fun connect(host: String, port: Int, user: String, keyPath: String, password: String = "") {
        viewModelScope.launch {
            val result = sshManager.connect(
                host, port, user, keyPath, password,
                onDisconnect = {
                    _isConnected.value = false
                    startReconnect()
                }
            )
            if (result.isSuccess) {
                _isConnected.value = true
                _errorMessage.value = null
                startForegroundService()
                startAutoRefresh()
            } else {
                _errorMessage.value = "接続失敗: ${result.exceptionOrNull()?.message}"
            }
        }
    }

    private fun startAutoRefresh() {
        refreshJob?.cancel()
        refreshJob = viewModelScope.launch {
            while (isActive) {
                if (!paused && sshManager.isConnected()) {
                    val result = sshManager.execCommand("${Defaults.TMUX} capture-pane -t ${tmuxTarget()} -p -e -S -500")
                    if (result.isSuccess) {
                        _paneContent.value = result.getOrDefault("")
                        _errorMessage.value = null
                    } else {
                        _errorMessage.value = result.exceptionOrNull()?.message
                    }
                }
                delay(3000)
            }
        }
    }

    fun sendCommand(text: String) {
        viewModelScope.launch {
            val target = tmuxTarget()
            val escaped = text.replace("'", "'\\''")
            // Send text and Enter SEPARATELY with 0.3s gap (Claude Code requirement)
            sshManager.execCommand("${Defaults.TMUX} send-keys -t $target '$escaped'")
            delay(300)
            sshManager.execCommand("${Defaults.TMUX} send-keys -t $target Enter")
            delay(1500)
            if (sshManager.isConnected()) {
                val result = sshManager.execCommand("${Defaults.TMUX} capture-pane -t $target -p -e -S -500")
                if (result.isSuccess) {
                    _paneContent.value = result.getOrDefault("")
                }
            }
        }
    }

    private fun startReconnect() {
        reconnectJob?.cancel()
        reconnectJob = viewModelScope.launch {
            _paneContent.value += "\n[自動再接続中...]\n"
            val result = sshManager.reconnect(maxAttempts = 3, delayMs = 5000)
            if (result.isSuccess) {
                _isConnected.value = true
                _errorMessage.value = null
                _paneContent.value += "[再接続成功]\n"
                startForegroundService()
                startAutoRefresh()
            } else {
                _isConnected.value = false
                _errorMessage.value = "再接続失敗: ${result.exceptionOrNull()?.message}"
                _paneContent.value += "[再接続失敗。手動で再接続してください]\n"
                stopForegroundService()
            }
        }
    }

    private fun startForegroundService() {
        try {
            val ctx = getApplication<Application>()
            val intent = Intent(ctx, SshForegroundService::class.java)
            ctx.startForegroundService(intent)
        } catch (_: Exception) {
            // Foreground service start blocked by system — SSH works without it
        }
    }

    private fun stopForegroundService() {
        val ctx = getApplication<Application>()
        val intent = Intent(ctx, SshForegroundService::class.java)
        ctx.stopService(intent)
    }

    override fun onCleared() {
        super.onCleared()
        refreshJob?.cancel()
        reconnectJob?.cancel()
    }
}
