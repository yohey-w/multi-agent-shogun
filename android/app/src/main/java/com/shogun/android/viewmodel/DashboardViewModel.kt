package com.shogun.android.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.shogun.android.data.ProfileRepository
import com.shogun.android.ssh.SshManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class DashboardViewModel(
    application: Application,
    private val profileRepository: ProfileRepository
) : AndroidViewModel(application) {

    private val sshManager = SshManager.getInstance()

    private val _markdownContent = MutableStateFlow("")
    val markdownContent: StateFlow<String> = _markdownContent

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    fun connect() {
        viewModelScope.launch {
            val activeId = profileRepository.getActiveProfileId()
            val profiles = profileRepository.loadProfiles()
            val activeProfile = profiles.find { it.id == activeId } ?: profiles.firstOrNull()
            if (activeProfile == null) {
                _errorMessage.value = "プロファイルが設定されていません。設定画面でプロファイルを作成してください"
                return@launch
            }
            val result = sshManager.connect(
                activeProfile.sshHost,
                activeProfile.sshPort,
                activeProfile.sshUser,
                activeProfile.sshKeyPath,
                activeProfile.sshPassword
            )
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
            val activeId = profileRepository.getActiveProfileId()
            val profiles = profileRepository.loadProfiles()
            val activeProfile = profiles.find { it.id == activeId } ?: profiles.firstOrNull()
            val projectPath = activeProfile?.projectPath ?: ""
            val dashboardFile = activeProfile?.dashboardFileName ?: "dashboard.md"
            if (projectPath.isBlank()) {
                _errorMessage.value = "設定画面でプロジェクトパスを設定してください"
                _isLoading.value = false
                return@launch
            }
            val result = sshManager.execCommand("cat $projectPath/$dashboardFile")
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
