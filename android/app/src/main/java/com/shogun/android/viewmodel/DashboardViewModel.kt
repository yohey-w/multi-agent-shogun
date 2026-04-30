package com.shogun.android.viewmodel

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.shogun.android.ssh.SshManager
import com.shogun.android.util.PrefsKeys
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class DashboardViewModel(application: Application) : AndroidViewModel(application) {

    private val sshManager = SshManager.getInstance()
    private val prefs = application.getSharedPreferences(PrefsKeys.PREFS_NAME, Context.MODE_PRIVATE)

    private val _markdownContent = MutableStateFlow("")
    val markdownContent: StateFlow<String> = _markdownContent

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    fun connect(host: String, port: Int, user: String, keyPath: String, password: String = "") {
        viewModelScope.launch {
            val result = sshManager.connect(host, port, user, keyPath, password)
            if (result.isSuccess) {
                _isConnected.value = true
                loadDashboard()
            } else {
                _errorMessage.value = "接続失敗: ${result.exceptionOrNull()?.message}"
            }
        }
    }

    fun loadDashboard() {
        viewModelScope.launch {
            _isLoading.value = true
            val projectPath = prefs.getString(PrefsKeys.PROJECT_PATH, "") ?: ""
            if (projectPath.isBlank()) {
                _errorMessage.value = "設定画面でプロジェクトパスを設定してください"
                _isLoading.value = false
                return@launch
            }
            val result = sshManager.execCommand("cat $projectPath/dashboard.md")
            if (result.isSuccess) {
                _markdownContent.value = result.getOrDefault("")
                _errorMessage.value = null
            } else {
                _errorMessage.value = result.exceptionOrNull()?.message
            }
            _isLoading.value = false
        }
    }

    override fun onCleared() {
        super.onCleared()
        // Do NOT disconnect the shared singleton SshManager here.
        // Tab navigation triggers onCleared, killing the connection for all ViewModels.
    }
}
