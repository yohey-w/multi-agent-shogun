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
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import com.shogun.android.ui.theme.*
import com.shogun.android.util.Defaults
import com.shogun.android.util.PrefsKeys
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.shogun.android.util.AppLogger
import com.shogun.android.viewmodel.SettingsViewModel
import java.io.File

@Composable
fun SettingsScreen(settingsViewModel: SettingsViewModel = viewModel()) {
    val context = LocalContext.current
    val prefs = context.getSharedPreferences(PrefsKeys.PREFS_NAME, Context.MODE_PRIVATE)

    var host by remember { mutableStateOf(prefs.getString(PrefsKeys.SSH_HOST, Defaults.SSH_HOST) ?: Defaults.SSH_HOST) }
    var port by remember { mutableStateOf(prefs.getString(PrefsKeys.SSH_PORT, Defaults.SSH_PORT_STR) ?: Defaults.SSH_PORT_STR) }
    var user by remember { mutableStateOf(prefs.getString(PrefsKeys.SSH_USER, "") ?: "") }
    var keyPath by remember { mutableStateOf(prefs.getString(PrefsKeys.SSH_KEY_PATH, "") ?: "") }
    var password by remember { mutableStateOf(prefs.getString(PrefsKeys.SSH_PASSWORD, "") ?: "") }
    var projectPath by remember { mutableStateOf(prefs.getString(PrefsKeys.PROJECT_PATH, "") ?: "") }
    var shogunSession by remember { mutableStateOf(prefs.getString(PrefsKeys.SHOGUN_SESSION, Defaults.SHOGUN_SESSION) ?: Defaults.SHOGUN_SESSION) }
    var agentsSession by remember { mutableStateOf(prefs.getString(PrefsKeys.AGENTS_SESSION, Defaults.AGENTS_SESSION) ?: Defaults.AGENTS_SESSION) }

    var saved by remember { mutableStateOf(false) }
    var tapCount by remember { mutableIntStateOf(0) }
    var showDebugLog by remember { mutableStateOf(false) }
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

    // Debug log dialog
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
            "SSH設定",
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

        OutlinedTextField(
            value = host,
            onValueChange = { host = it },
            label = { Text("SSHホスト") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        OutlinedTextField(
            value = port,
            onValueChange = { port = it },
            label = { Text("SSHポート") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
        )

        OutlinedTextField(
            value = user,
            onValueChange = { user = it },
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
                onValueChange = {
                    keyPath = it
                    saved = false
                },
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
            onValueChange = { password = it },
            label = { Text("SSHパスワード（鍵なし時に使用）") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            visualTransformation = PasswordVisualTransformation()
        )

        Divider()

        Text("プロジェクト設定", style = MaterialTheme.typography.titleMedium, color = Kinpaku)

        OutlinedTextField(
            value = projectPath,
            onValueChange = { projectPath = it },
            label = { Text("プロジェクトパス（サーバー側）") },
            placeholder = { Text("/path/to/multi-agent-shogun") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        Divider()

        Text("セッション設定", style = MaterialTheme.typography.titleMedium, color = Kinpaku)

        OutlinedTextField(
            value = shogunSession,
            onValueChange = { shogunSession = it },
            label = { Text("将軍セッション名") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        OutlinedTextField(
            value = agentsSession,
            onValueChange = { agentsSession = it },
            label = { Text("エージェントセッション名") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        Divider()

        NtfySettingsSection(viewModel = settingsViewModel)

        Divider()

        Button(
            onClick = {
                prefs.edit()
                    .putString(PrefsKeys.SSH_HOST, host)
                    .putString(PrefsKeys.SSH_PORT, port)
                    .putString(PrefsKeys.SSH_USER, user)
                    .putString(PrefsKeys.SSH_KEY_PATH, keyPath)
                    .putString(PrefsKeys.SSH_PASSWORD, password)
                    .putString(PrefsKeys.PROJECT_PATH, projectPath)
                    .putString(PrefsKeys.SHOGUN_SESSION, shogunSession)
                    .putString(PrefsKeys.AGENTS_SESSION, agentsSession)
                    .apply()
                saved = true
            },
            modifier = Modifier.fillMaxWidth(),
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
                // Copy to clipboard button
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
