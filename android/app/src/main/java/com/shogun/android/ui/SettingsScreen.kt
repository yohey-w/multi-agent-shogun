package com.shogun.android.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.shogun.android.data.Profile
import com.shogun.android.ui.theme.*
import com.shogun.android.util.AppLogger
import com.shogun.android.util.Defaults
import com.shogun.android.viewmodel.ProfileViewModel
import com.shogun.android.viewmodel.SettingsViewModel
import java.io.File

@Composable
fun SettingsScreen(
    profileViewModel: ProfileViewModel,
    settingsViewModel: SettingsViewModel = viewModel()
) {
    val context = LocalContext.current
    val profiles by profileViewModel.profiles.collectAsState()
    val activeProfile by profileViewModel.activeProfile.collectAsState()

    var editingProfileId by remember { mutableStateOf(activeProfile?.id) }

    // Keep editingProfileId valid: if the profile was deleted, fall back to active
    LaunchedEffect(profiles) {
        if (editingProfileId != null && profiles.none { it.id == editingProfileId }) {
            editingProfileId = activeProfile?.id
        }
    }

    val editingProfile = profiles.find { it.id == editingProfileId } ?: activeProfile

    // Dialog states
    var showAddDialog by remember { mutableStateOf(false) }
    var addNameInput by remember { mutableStateOf("") }
    var duplicateSourceId by remember { mutableStateOf<String?>(null) }
    var duplicateNameInput by remember { mutableStateOf("") }
    var tapCount by remember { mutableIntStateOf(0) }
    var showDebugLog by remember { mutableStateOf(false) }

    // Add profile dialog
    if (showAddDialog) {
        AlertDialog(
            onDismissRequest = { showAddDialog = false; addNameInput = "" },
            containerColor = Shikkoku,
            title = { Text("新規プロファイル", color = Kinpaku) },
            text = {
                OutlinedTextField(
                    value = addNameInput,
                    onValueChange = { addNameInput = it },
                    label = { Text("プロファイル名") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val trimmed = addNameInput.trim()
                        if (trimmed.isNotBlank()) {
                            val newProfile = Profile(name = trimmed)
                            profileViewModel.addProfile(newProfile)
                            editingProfileId = newProfile.id
                            addNameInput = ""
                            showAddDialog = false
                        }
                    },
                    enabled = addNameInput.isNotBlank()
                ) { Text("作成", color = Kinpaku) }
            },
            dismissButton = {
                TextButton(onClick = { showAddDialog = false; addNameInput = "" }) {
                    Text("キャンセル", color = TextMuted)
                }
            }
        )
    }

    // Duplicate profile dialog
    duplicateSourceId?.let { sourceId ->
        AlertDialog(
            onDismissRequest = { duplicateSourceId = null; duplicateNameInput = "" },
            containerColor = Shikkoku,
            title = { Text("プロファイルを複製", color = Kinpaku) },
            text = {
                OutlinedTextField(
                    value = duplicateNameInput,
                    onValueChange = { duplicateNameInput = it },
                    label = { Text("新しいプロファイル名") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val trimmed = duplicateNameInput.trim()
                        if (trimmed.isNotBlank()) {
                            val result = profileViewModel.duplicateProfile(sourceId, trimmed)
                            if (result != null) {
                                editingProfileId = result.id
                            } else {
                                Toast.makeText(context, "複製に失敗しました", Toast.LENGTH_SHORT).show()
                            }
                            duplicateSourceId = null
                            duplicateNameInput = ""
                        }
                    },
                    enabled = duplicateNameInput.isNotBlank()
                ) { Text("複製", color = Kinpaku) }
            },
            dismissButton = {
                TextButton(onClick = { duplicateSourceId = null; duplicateNameInput = "" }) {
                    Text("キャンセル", color = TextMuted)
                }
            }
        )
    }

    if (showDebugLog) {
        DebugLogDialog(onDismiss = { showDebugLog = false })
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Shikkoku)
            .padding(16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            "プロファイル管理",
            style = MaterialTheme.typography.titleLarge,
            color = Kinpaku,
            modifier = Modifier.clickable {
                tapCount++
                if (tapCount >= 7) {
                    showDebugLog = true
                    tapCount = 0
                }
            }
        )

        ProfileListSection(
            profiles = profiles,
            activeProfileId = activeProfile?.id,
            editingProfileId = editingProfileId,
            onProfileClick = { id ->
                editingProfileId = id
            },
            onAddClick = { showAddDialog = true },
            onDuplicateClick = { id ->
                val source = profiles.find { it.id == id }
                duplicateNameInput = "${source?.name ?: "プロファイル"}_コピー"
                duplicateSourceId = id
            },
            onDeleteClick = { id ->
                if (id == activeProfile?.id) {
                    Toast.makeText(context, "現在選択中のプロファイルは削除できません", Toast.LENGTH_SHORT).show()
                } else {
                    profileViewModel.deleteProfile(id)
                }
            }
        )

        if (editingProfile != null) {
            Divider(color = Sumi)
            Text("プロファイル設定", style = MaterialTheme.typography.titleMedium, color = Kinpaku)
            ProfileEditSection(
                profile = editingProfile,
                onSave = { updated -> profileViewModel.updateProfile(updated) }
            )
        } else {
            Text(
                "プロファイルを追加してください",
                color = TextMuted,
                style = MaterialTheme.typography.bodyMedium
            )
        }

        Divider(color = Sumi)
        NtfySettingsSection(viewModel = settingsViewModel)
    }
}

@Composable
private fun ProfileListSection(
    profiles: List<Profile>,
    activeProfileId: String?,
    editingProfileId: String?,
    onProfileClick: (String) -> Unit,
    onAddClick: () -> Unit,
    onDuplicateClick: (String) -> Unit,
    onDeleteClick: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        profiles.forEach { profile ->
            ProfileListItem(
                profile = profile,
                isActive = profile.id == activeProfileId,
                isEditing = profile.id == editingProfileId,
                onClick = { onProfileClick(profile.id) },
                onDuplicate = { onDuplicateClick(profile.id) },
                onDelete = { onDeleteClick(profile.id) }
            )
        }
        OutlinedButton(
            onClick = onAddClick,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(4.dp)
        ) {
            Text("＋ プロファイルを追加", color = Kinpaku)
        }
    }
}

@Composable
private fun ProfileListItem(
    profile: Profile,
    isActive: Boolean,
    isEditing: Boolean,
    onClick: () -> Unit,
    onDuplicate: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        color = if (isEditing) Sumi else Color.Transparent,
        shape = RoundedCornerShape(4.dp),
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.weight(1f)
            ) {
                RadioButton(
                    selected = isEditing,
                    onClick = onClick,
                    colors = RadioButtonDefaults.colors(
                        selectedColor = Kinpaku,
                        unselectedColor = TextMuted
                    )
                )
                Text(
                    text = profile.name,
                    color = if (isActive) Kinpaku else Zouge,
                    style = MaterialTheme.typography.bodyMedium
                )
            }
            Row {
                IconButton(onClick = onDuplicate) {
                    Icon(Icons.Default.ContentCopy, contentDescription = "複製", tint = TextMuted)
                }
                IconButton(onClick = onDelete) {
                    Icon(Icons.Default.Delete, contentDescription = "削除", tint = Shuaka)
                }
            }
        }
    }
}

@Composable
private fun ProfileEditSection(
    profile: Profile,
    onSave: (Profile) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current

    // Form state keyed to profile.id — resets when switching to a different profile
    var name by remember(profile.id) { mutableStateOf(profile.name) }
    var host by remember(profile.id) { mutableStateOf(profile.sshHost) }
    var port by remember(profile.id) { mutableStateOf(profile.sshPort.toString()) }
    var user by remember(profile.id) { mutableStateOf(profile.sshUser) }
    var keyPath by remember(profile.id) { mutableStateOf(profile.sshKeyPath) }
    var password by remember(profile.id) { mutableStateOf(profile.sshPassword) }
    var projectPath by remember(profile.id) { mutableStateOf(profile.projectPath) }
    var shogunSession by remember(profile.id) { mutableStateOf(profile.shogunSession) }
    var agentsSession by remember(profile.id) { mutableStateOf(profile.agentsSession) }
    var dashboardFileName by remember(profile.id) { mutableStateOf(profile.dashboardFileName) }
    var saved by remember(profile.id) { mutableStateOf(false) }

    val pickSshKeyLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        runCatching { copySshKeyToAppStorage(context, uri) }
            .onSuccess { importedPath ->
                keyPath = importedPath
                saved = false
                Toast.makeText(context, "秘密鍵をアプリ領域へコピーしたでござる", Toast.LENGTH_SHORT).show()
            }
            .onFailure { error ->
                Toast.makeText(context, "秘密鍵取込失敗: ${error.message}", Toast.LENGTH_LONG).show()
            }
    }

    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        OutlinedTextField(
            value = name,
            onValueChange = { name = it; saved = false },
            label = { Text("プロファイル名") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        Text("SSH設定", style = MaterialTheme.typography.titleSmall, color = Kinpaku)

        OutlinedTextField(
            value = host,
            onValueChange = { host = it; saved = false },
            label = { Text("SSHホスト") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        OutlinedTextField(
            value = port,
            onValueChange = { port = it; saved = false },
            label = { Text("SSHポート") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
        )

        OutlinedTextField(
            value = user,
            onValueChange = { user = it; saved = false },
            label = { Text("SSHユーザー") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = keyPath,
                onValueChange = { keyPath = it; saved = false },
                label = { Text("SSH秘密鍵パス") },
                modifier = Modifier.weight(1f),
                singleLine = true
            )
            OutlinedButton(
                onClick = { pickSshKeyLauncher.launch(arrayOf("*/*")) },
                modifier = Modifier.defaultMinSize(minHeight = 56.dp),
                shape = RoundedCornerShape(4.dp)
            ) {
                Text("ファイルを選択")
            }
        }

        OutlinedTextField(
            value = password,
            onValueChange = { password = it; saved = false },
            label = { Text("SSHパスワード（鍵なし時に使用）") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            visualTransformation = PasswordVisualTransformation()
        )

        Divider(color = Sumi)
        Text("プロジェクト設定", style = MaterialTheme.typography.titleSmall, color = Kinpaku)

        OutlinedTextField(
            value = projectPath,
            onValueChange = { projectPath = it; saved = false },
            label = { Text("プロジェクトパス（サーバー側）") },
            placeholder = { Text("/path/to/multi-agent-shogun") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        Divider(color = Sumi)
        Text("セッション設定", style = MaterialTheme.typography.titleSmall, color = Kinpaku)

        OutlinedTextField(
            value = shogunSession,
            onValueChange = { shogunSession = it; saved = false },
            label = { Text("将軍セッション名") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        OutlinedTextField(
            value = agentsSession,
            onValueChange = { agentsSession = it; saved = false },
            label = { Text("エージェントセッション名") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        OutlinedTextField(
            value = dashboardFileName,
            onValueChange = { dashboardFileName = it; saved = false },
            label = { Text("ダッシュボードファイル名") },
            placeholder = { Text("dashboard.md") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        Button(
            onClick = {
                if (name.isNotBlank()) {
                    val updated = profile.copy(
                        name = name.trim(),
                        sshHost = host.trim(),
                        sshPort = port.toIntOrNull() ?: Defaults.SSH_PORT,
                        sshUser = user.trim(),
                        sshKeyPath = keyPath.trim(),
                        sshPassword = password,
                        projectPath = projectPath.trim(),
                        shogunSession = shogunSession.trim(),
                        agentsSession = agentsSession.trim(),
                        dashboardFileName = dashboardFileName.trim().ifBlank { "dashboard.md" }
                    )
                    onSave(updated)
                    saved = true
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = name.isNotBlank(),
            colors = ButtonDefaults.buttonColors(
                containerColor = Shuaka,
                contentColor = Color.White
            ),
            shape = RoundedCornerShape(4.dp)
        ) {
            Text("保存")
        }

        if (saved) {
            Text(
                text = "設定を保存しました",
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

private fun copySshKeyToAppStorage(context: Context, uri: Uri): String {
    val resolver = context.contentResolver
    val displayName = resolver.query(
        uri,
        arrayOf(OpenableColumns.DISPLAY_NAME),
        null,
        null,
        null
    )?.use { cursor ->
        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
        if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
    }
    val sanitizedName = (displayName ?: "ssh_key.pem").replace(Regex("[^A-Za-z0-9._-]"), "_")
    val keyDir = File(context.filesDir, "ssh_keys")
    if (!keyDir.exists() && !keyDir.mkdirs()) {
        error("鍵保存先を作成できませぬ")
    }
    val targetFile = File(keyDir, "${System.currentTimeMillis()}_$sanitizedName")

    resolver.openInputStream(uri)?.use { input ->
        targetFile.outputStream().use { output ->
            input.copyTo(output)
        }
    } ?: error("鍵ファイルを開けませぬ")

    return targetFile.absolutePath
}

@Composable
fun DebugLogDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    val entries = remember { AppLogger.getEntries() }
    val listState = rememberLazyListState()

    LaunchedEffect(entries.size) {
        if (entries.isNotEmpty()) listState.scrollToItem(entries.size - 1)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Shikkoku,
        title = {
            Text("Debug Log (${entries.size})", color = Kinpaku)
        },
        text = {
            Column {
                TextButton(onClick = {
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val clip = ClipData.newPlainText("debug_log", entries.joinToString("\n"))
                    clipboard.setPrimaryClip(clip)
                    Toast.makeText(context, "ログをコピーしました", Toast.LENGTH_SHORT).show()
                }) {
                    Text("Copy All", color = Kinpaku)
                }
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(380.dp)
                ) {
                    items(entries) { entry ->
                        Text(
                            text = entry,
                            color = if (entry.contains("FAIL") || entry.contains("ERROR"))
                                Color(0xFFCC3333) else Color(0xFFAABBCC),
                            fontFamily = FontFamily.Monospace,
                            fontSize = 10.sp,
                            modifier = Modifier.padding(vertical = 1.dp)
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                AppLogger.clear()
                onDismiss()
            }) {
                Text("Clear & Close", color = Kinpaku)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Close", color = Color(0xFF888888))
            }
        }
    )
}
