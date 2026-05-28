package com.shogun.android.data

import android.content.SharedPreferences
import com.shogun.android.util.PrefsKeys
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

interface ProfileRepository {
    fun loadProfiles(): List<Profile>
    fun saveProfiles(profiles: List<Profile>)
    fun addProfile(profile: Profile)
    fun updateProfile(profile: Profile)
    fun deleteProfile(id: String)
    fun getActiveProfileId(): String?
    fun setActiveProfileId(id: String)
}

class SharedPreferencesProfileRepository(
    private val prefs: SharedPreferences
) : ProfileRepository {

    private val json = Json { ignoreUnknownKeys = true }

    override fun loadProfiles(): List<Profile> {
        val jsonStr = prefs.getString(PrefsKeys.PROFILES_JSON, null) ?: return emptyList()
        return runCatching { json.decodeFromString<List<Profile>>(jsonStr) }
            .getOrDefault(emptyList())
    }

    override fun saveProfiles(profiles: List<Profile>) {
        prefs.edit()
            .putString(PrefsKeys.PROFILES_JSON, json.encodeToString(profiles))
            .apply()
    }

    override fun addProfile(profile: Profile) {
        saveProfiles(loadProfiles() + profile)
    }

    override fun updateProfile(profile: Profile) {
        saveProfiles(loadProfiles().map { if (it.id == profile.id) profile else it })
    }

    override fun deleteProfile(id: String) {
        saveProfiles(loadProfiles().filter { it.id != id })
    }

    override fun getActiveProfileId(): String? =
        prefs.getString(PrefsKeys.ACTIVE_PROFILE_ID, null)

    override fun setActiveProfileId(id: String) {
        prefs.edit().putString(PrefsKeys.ACTIVE_PROFILE_ID, id).apply()
    }
}
