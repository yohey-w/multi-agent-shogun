package com.shogun.android.viewmodel

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.shogun.android.data.Profile
import com.shogun.android.data.ProfileRepository
import com.shogun.android.data.SharedPreferencesProfileRepository
import com.shogun.android.util.PrefsKeys
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

class ProfileViewModel(
    application: Application,
    private val repository: ProfileRepository
) : AndroidViewModel(application) {

    private val _profiles = MutableStateFlow<List<Profile>>(emptyList())
    val profiles: StateFlow<List<Profile>> = _profiles.asStateFlow()

    private val _activeProfile = MutableStateFlow<Profile?>(null)
    val activeProfile: StateFlow<Profile?> = _activeProfile.asStateFlow()

    init {
        val loaded = repository.loadProfiles()
        _profiles.value = loaded
        val activeId = repository.getActiveProfileId()
        _activeProfile.value = loaded.find { it.id == activeId } ?: loaded.firstOrNull()
    }

    fun selectProfile(id: String) {
        val profile = _profiles.value.find { it.id == id } ?: return
        setActiveProfileInternal(profile)
    }

    private fun setActiveProfileInternal(profile: Profile?) {
        if (profile != null) {
            repository.setActiveProfileId(profile.id)
            syncToPrefs(profile)
        }
        _activeProfile.value = profile
    }

    private fun syncToPrefs(profile: Profile) {
        val prefs = getApplication<Application>().getSharedPreferences(
            PrefsKeys.PREFS_NAME, Context.MODE_PRIVATE
        )
        prefs.edit()
            .putString(PrefsKeys.SSH_HOST, profile.sshHost)
            .putString(PrefsKeys.SSH_PORT, profile.sshPort.toString())
            .putString(PrefsKeys.SSH_USER, profile.sshUser)
            .putString(PrefsKeys.SSH_KEY_PATH, profile.sshKeyPath)
            .putString(PrefsKeys.SSH_PASSWORD, profile.sshPassword)
            .putString(PrefsKeys.PROJECT_PATH, profile.projectPath)
            .putString(PrefsKeys.SHOGUN_SESSION, profile.shogunSession)
            .putString(PrefsKeys.AGENTS_SESSION, profile.agentsSession)
            .commit()
    }

    fun addProfile(profile: Profile) {
        repository.addProfile(profile)
        _profiles.value = repository.loadProfiles()
    }

    fun duplicateProfile(sourceId: String, newName: String): Profile? {
        val source = _profiles.value.find { it.id == sourceId } ?: return null
        val copy = source.copy(id = UUID.randomUUID().toString(), name = newName)
        addProfile(copy)
        return copy
    }

    fun deleteProfile(id: String) {
        repository.deleteProfile(id)
        val updated = repository.loadProfiles()
        _profiles.value = updated
        if (_activeProfile.value?.id == id) {
            setActiveProfileInternal(updated.firstOrNull())
        }
    }

    fun updateProfile(profile: Profile) {
        repository.updateProfile(profile)
        _profiles.value = repository.loadProfiles()
        if (_activeProfile.value?.id == profile.id) {
            setActiveProfileInternal(profile)
        }
    }

    companion object {
        fun factory(application: Application): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    val prefs = application.getSharedPreferences(
                        PrefsKeys.PREFS_NAME, Context.MODE_PRIVATE
                    )
                    @Suppress("UNCHECKED_CAST")
                    return ProfileViewModel(
                        application,
                        SharedPreferencesProfileRepository(prefs)
                    ) as T
                }
            }
    }
}
