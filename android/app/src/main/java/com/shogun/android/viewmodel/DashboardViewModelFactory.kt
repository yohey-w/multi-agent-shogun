package com.shogun.android.viewmodel

import android.app.Application
import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.shogun.android.data.ProfileRepository
import com.shogun.android.data.SharedPreferencesProfileRepository
import com.shogun.android.util.PrefsKeys

class DashboardViewModelFactory(
    private val application: Application
) : ViewModelProvider.Factory {

    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        val prefs = application.getSharedPreferences(PrefsKeys.PREFS_NAME, Context.MODE_PRIVATE)
        val repository: ProfileRepository = SharedPreferencesProfileRepository(prefs)
        @Suppress("UNCHECKED_CAST")
        return DashboardViewModel(application, repository) as T
    }
}
