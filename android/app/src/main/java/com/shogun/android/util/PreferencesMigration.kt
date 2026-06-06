package com.shogun.android.util

import android.content.Context

private const val MIGRATION_FLAG = "encrypted_migration_v1"

object PreferencesMigration {
    fun migrateIfNeeded(context: Context) {
        val encryptedPrefs = EncryptedPrefsProvider.getPreferences(context)
        if (encryptedPrefs.contains(MIGRATION_FLAG)) return

        val oldPrefs = context.getSharedPreferences(PrefsKeys.PREFS_NAME, Context.MODE_PRIVATE)
        val oldAll = oldPrefs.all

        val editor = encryptedPrefs.edit()
        for ((key, value) in oldAll) {
            when (value) {
                is String -> editor.putString(key, value)
                is Boolean -> editor.putBoolean(key, value)
                is Int -> editor.putInt(key, value)
                is Long -> editor.putLong(key, value)
                is Float -> editor.putFloat(key, value)
                is Set<*> -> {
                    @Suppress("UNCHECKED_CAST")
                    editor.putStringSet(key, value as Set<String>)
                }
            }
        }
        editor.putBoolean(MIGRATION_FLAG, true)
        editor.commit()

        if (oldAll.isNotEmpty()) {
            oldPrefs.edit().clear().commit()
        }
    }
}
