package com.shogun.android

import android.Manifest
import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.lifecycleScope
import com.shogun.android.data.Profile
import com.shogun.android.data.SharedPreferencesProfileRepository
import com.shogun.android.ssh.SshManager
import com.shogun.android.util.EncryptedPrefsProvider
import com.shogun.android.util.PreferencesMigration
import kotlinx.coroutines.launch
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.shogun.android.ui.AgentsScreen
import com.shogun.android.ui.DashboardScreen
import com.shogun.android.ui.SettingsScreen
import com.shogun.android.ui.ShogunScreen
import com.shogun.android.ui.theme.*
import com.shogun.android.util.PrefsKeys
import com.shogun.android.viewmodel.ProfileViewModel

sealed class Screen(val route: String, val label: String, val icon: ImageVector) {
    object Shogun : Screen("shogun", "将軍", Icons.Default.Star)
    object Agents : Screen("agents", "エージェント", Icons.Default.List)
    object Dashboard : Screen("dashboard", "戦況", Icons.Default.Home)
    object Settings : Screen("settings", "設定", Icons.Default.Settings)
}

val bottomNavItems = listOf(
    Screen.Shogun,
    Screen.Agents,
    Screen.Dashboard,
    Screen.Settings
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        PreferencesMigration.migrateIfNeeded(this)
        enableEdgeToEdge()
        NotificationHelper.initChannels(this)
        setContent {
            ShogunTheme {
                ShogunApp()
            }
        }
        handleShareIntent(intent)
        val hasNotifPerm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else true
        if (hasNotifPerm && EncryptedPrefsProvider.getPreferences(this)
                .getBoolean(PrefsKeys.NOTIFICATION_ENABLED, true)) {
            try {
                startForegroundService(Intent(this, NtfyService::class.java))
            } catch (_: Exception) {
                // Foreground service start blocked by system — skip silently
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent) {
        val imageUris: List<Uri> = when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
                listOfNotNull(uri)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                } ?: emptyList()
            }
            else -> return
        }
        if (imageUris.isEmpty()) return

        val sshManager = SshManager.getInstance()
        if (!sshManager.isConnected()) {
            Toast.makeText(this, "❌ SSH未接続。先にアプリを開いて接続してください", Toast.LENGTH_LONG).show()
            return
        }

        val prefs = EncryptedPrefsProvider.getPreferences(this)
        val repository = SharedPreferencesProfileRepository(prefs)
        val activeId = repository.getActiveProfileId()
        val activeProfile = repository.loadProfiles().let { profiles ->
            profiles.find { it.id == activeId } ?: profiles.firstOrNull()
        }
        // Fallback to legacy prefs key for users who haven't migrated to profiles yet
        val projectPath = activeProfile?.projectPath
            ?: prefs.getString(PrefsKeys.PROJECT_PATH, "") ?: ""

        if (projectPath.isBlank()) {
            Toast.makeText(this, "❌ 設定画面でプロジェクトパスを設定してください", Toast.LENGTH_LONG).show()
            return
        }
        val total = imageUris.size
        Toast.makeText(this, "転送中... (${total}枚)", Toast.LENGTH_SHORT).show()
        lifecycleScope.launch {
            var success = 0
            var failed = 0
            for (uri in imageUris) {
                sshManager.uploadScreenshot(this@MainActivity, uri, projectPath).fold(
                    onSuccess = { success++ },
                    onFailure = { failed++ }
                )
            }
            val msg = if (failed == 0) "✅ ${success}枚 転送完了" else "✅ ${success}枚 完了 / ❌ ${failed}枚 失敗"
            Toast.makeText(this@MainActivity, msg, Toast.LENGTH_LONG).show()
        }
    }
}

@Composable
fun ShogunApp() {
    val context = LocalContext.current
    val application = context.applicationContext as Application
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // Profile ViewModel — Activity scoped (hoisted here, shared across screens)
    val profileViewModel: ProfileViewModel = viewModel(factory = ProfileViewModel.factory(application))
    val activeProfile by profileViewModel.activeProfile.collectAsState()
    val profiles by profileViewModel.profiles.collectAsState()

    // BGM — 3 tracks, tap to cycle: shogun → shogun_reiwa → shogun_ashigirls → OFF → shogun ...
    data class BgmTrack(val resId: Int, val label: String)
    val tracks = remember { listOf(
        BgmTrack(R.raw.shogun, "将軍"),
        BgmTrack(R.raw.shogun_reiwa, "令和"),
        BgmTrack(R.raw.shogun_ashigirls, "足軽ガールズ")
    ) }
    var currentTrackIndex by remember { mutableIntStateOf(-1) } // -1 = OFF
    var isBgmPlaying by remember { mutableStateOf(false) }
    var bgmTrackLabel by remember { mutableStateOf("") }
    val audioManager = remember { context.getSystemService(Context.AUDIO_SERVICE) as AudioManager }
    var mediaPlayer by remember { mutableStateOf<MediaPlayer?>(null) }

    // AudioFocus
    val focusRequest = remember {
        AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setOnAudioFocusChangeListener { focusChange ->
                when (focusChange) {
                    AudioManager.AUDIOFOCUS_LOSS -> {
                        mediaPlayer?.pause()
                        isBgmPlaying = false
                    }
                }
            }
            .build()
    }

    fun switchTrack(index: Int) {
        mediaPlayer?.release()
        if (index < 0) {
            mediaPlayer = null
            audioManager.abandonAudioFocusRequest(focusRequest)
            isBgmPlaying = false
            currentTrackIndex = -1
            bgmTrackLabel = ""
            return
        }
        val track = tracks[index]
        mediaPlayer = MediaPlayer.create(context, track.resId)?.apply {
            isLooping = true
            setVolume(1.0f, 1.0f)
        }
        audioManager.requestAudioFocus(focusRequest)
        mediaPlayer?.start()
        currentTrackIndex = index
        isBgmPlaying = true
        bgmTrackLabel = track.label
    }

    DisposableEffect(Unit) {
        onDispose {
            audioManager.abandonAudioFocusRequest(focusRequest)
            mediaPlayer?.release()
        }
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            var showProfileMenu by remember { mutableStateOf(false) }
            NavigationBar(
                containerColor = Shikkoku,
                contentColor = Kinpaku,
            ) {
                bottomNavItems.filter { it != Screen.Settings }.forEach { screen ->
                    NavigationBarItem(
                        icon = { Icon(screen.icon, contentDescription = screen.label) },
                        label = { Text(screen.label, fontSize = 10.sp, maxLines = 1) },
                        selected = currentRoute == screen.route,
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Kinpaku,
                            selectedTextColor = Kinpaku,
                            unselectedIconColor = TextMuted,
                            unselectedTextColor = TextMuted,
                            indicatorColor = Sumi,
                        ),
                        onClick = {
                            navController.navigate(screen.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    )
                }
                NavigationBarItem(
                    icon = {
                        Box {
                            Icon(Icons.Default.Group, contentDescription = "プロファイル")
                            DropdownMenu(
                                expanded = showProfileMenu,
                                onDismissRequest = { showProfileMenu = false }
                            ) {
                                profiles.forEach { profile ->
                                    DropdownMenuItem(
                                        text = { Text(profile.name) },
                                        onClick = {
                                            profileViewModel.selectProfile(profile.id)
                                            showProfileMenu = false
                                        }
                                    )
                                }
                            }
                        }
                    },
                    label = { Text(activeProfile?.name ?: "プロファイル", fontSize = 10.sp, maxLines = 1) },
                    selected = false,
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Kinpaku,
                        selectedTextColor = Kinpaku,
                        unselectedIconColor = TextMuted,
                        unselectedTextColor = TextMuted,
                        indicatorColor = Sumi,
                    ),
                    onClick = { showProfileMenu = true }
                )
                NavigationBarItem(
                    icon = { Icon(Screen.Settings.icon, contentDescription = Screen.Settings.label) },
                    label = { Text(Screen.Settings.label, fontSize = 10.sp, maxLines = 1) },
                    selected = currentRoute == Screen.Settings.route,
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Kinpaku,
                        selectedTextColor = Kinpaku,
                        unselectedIconColor = TextMuted,
                        unselectedTextColor = TextMuted,
                        indicatorColor = Sumi,
                    ),
                    onClick = {
                        navController.navigate(Screen.Settings.route) {
                            popUpTo(navController.graph.findStartDestination().id) {
                                saveState = true
                            }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                )
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Shogun.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(Screen.Shogun.route) {
                key(activeProfile?.id) {
                    ShogunScreen(
                        profileId = activeProfile?.id,
                        mediaPlayer = mediaPlayer,
                        isBgmPlaying = isBgmPlaying,
                        bgmTrackLabel = bgmTrackLabel,
                        onBgmToggle = {
                            val nextIndex = if (currentTrackIndex < 0) 0
                                else if (currentTrackIndex >= tracks.size - 1) -1
                                else currentTrackIndex + 1
                            switchTrack(nextIndex)
                        }
                    )
                }
            }
            composable(Screen.Agents.route) {
                key(activeProfile?.id) { AgentsScreen(profileId = activeProfile?.id) }
            }
            composable(Screen.Dashboard.route) {
                key(activeProfile?.id) { DashboardScreen(profileId = activeProfile?.id) }
            }
            composable(Screen.Settings.route) {
                SettingsScreen(profileViewModel = profileViewModel)
            }
        }
    }
}
