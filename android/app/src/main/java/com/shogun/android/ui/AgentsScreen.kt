package com.shogun.android.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Speed
import androidx.core.content.ContextCompat
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.shogun.android.ui.theme.*
import com.shogun.android.util.Defaults
import com.shogun.android.util.PrefsKeys
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.shogun.android.R
import com.shogun.android.viewmodel.AgentsViewModel
import com.shogun.android.viewmodel.PaneInfo

// ── Rate limit data classes ──────────────────────────────────────────────────
private data class WindowInfo(val percent: Float, val resetStr: String)
private data class ClaudeMaxInfo(
    val window5h: WindowInfo?,
    val window7d: WindowInfo?,
    val sonnet7d: Float?,
    val opus7d: Float?,
    val todayTokens: String?,
    val sessions: Int?,
    val messages: Int?
)
private data class CodexQuotaInfo(
    val account5h: WindowInfo?,
    val account7d: WindowInfo?,
    val model5h: WindowInfo?,
    val model7d: WindowInfo?,
    val modelName: String?
)
private data class CodexEntry(val ashigaru: Int, val percent: Float?) // null = unknown

private data class RateLimitData(
    val claudeMax: ClaudeMaxInfo,
    val codexQuota: CodexQuotaInfo,
    val codexEntries: List<CodexEntry>
)

private fun parseRateLimitResult(text: String): RateLimitData {
    val window5h = Regex("""5h window:\s+([\d.]+)%.*\(resets ([^)]+)\)""").find(text)?.let {
        WindowInfo(it.groupValues[1].toFloatOrNull() ?: 0f, it.groupValues[2])
    }
    val window7d = Regex("""7d window:\s+([\d.]+)%.*\(resets ([^)]+)\)""").find(text)?.let {
        WindowInfo(it.groupValues[1].toFloatOrNull() ?: 0f, it.groupValues[2])
    }
    val sonnet7d = Regex("""sonnet 7d:\s+([\d.]+)%""").find(text)?.groupValues?.get(1)?.toFloatOrNull()
    val opus7d   = Regex("""opus 7d:\s+([\d.]+)%""").find(text)?.groupValues?.get(1)?.toFloatOrNull()
    val todayTokens = Regex("""Today:\s+([\d,]+) tokens""").find(text)?.groupValues?.get(1)
    val sessions = Regex("""Sessions:\s+(\d+)""").find(text)?.groupValues?.get(1)?.toIntOrNull()
    val messages = Regex("""Messages:\s+(\d+)""").find(text)?.groupValues?.get(1)?.toIntOrNull()

    val claudeMax = ClaudeMaxInfo(window5h, window7d, sonnet7d, opus7d, todayTokens, sessions, messages)

    // Codex quota: "5h limit: NN% left (resets HH:MM)" — note: "left" not "used"
    val quotaRegex5h = Regex("""5h limit:\s+(\d+)% left\s+\(resets ([^)]+)\)""")
    val quotaRegex7d = Regex("""Weekly limit:\s+(\d+)% left\s+\(resets ([^)]+)\)""")
    val all5h = quotaRegex5h.findAll(text).toList()
    val all7d = quotaRegex7d.findAll(text).toList()

    // First match = account-level, second = model-level
    val acct5h = all5h.getOrNull(0)?.let { WindowInfo(100f - (it.groupValues[1].toFloatOrNull() ?: 0f), it.groupValues[2]) }
    val acct7d = all7d.getOrNull(0)?.let { WindowInfo(100f - (it.groupValues[1].toFloatOrNull() ?: 0f), it.groupValues[2]) }
    val mdl5h  = all5h.getOrNull(1)?.let { WindowInfo(100f - (it.groupValues[1].toFloatOrNull() ?: 0f), it.groupValues[2]) }
    val mdl7d  = all7d.getOrNull(1)?.let { WindowInfo(100f - (it.groupValues[1].toFloatOrNull() ?: 0f), it.groupValues[2]) }
    val modelName = Regex("""Quota \(([^)]+)\)""").find(text)?.groupValues?.get(1)

    val codexQuota = CodexQuotaInfo(acct5h, acct7d, mdl5h, mdl7d, modelName)

    val codexEntries = mutableListOf<CodexEntry>()
    Regex("""(\d+):(\d+)%""").findAll(text).forEach { m ->
        val ash = m.groupValues[1].toIntOrNull() ?: return@forEach
        codexEntries.add(CodexEntry(ash, m.groupValues[2].toFloatOrNull()))
    }
    Regex("""(\d+):\?""").findAll(text).forEach { m ->
        val ash = m.groupValues[1].toIntOrNull() ?: return@forEach
        if (codexEntries.none { it.ashigaru == ash }) codexEntries.add(CodexEntry(ash, null))
    }
    codexEntries.sortBy { it.ashigaru }
    return RateLimitData(claudeMax, codexQuota, codexEntries)
}

private fun rateLimitBarColor(percent: Float): Color = when {
    percent >= 80f -> Color(0xFFCC4444)
    percent >= 50f -> Kinpaku
    else           -> Color(0xFF4CAF50)
}

private fun formatResetTime(resetStr: String): String {
    val locale = java.util.Locale.getDefault()
    val now = java.time.LocalDateTime.now()
    return try {
        if (resetStr.contains('T')) {
            val ldt = java.time.LocalDateTime.parse(resetStr.take(16))
            val dow = ldt.dayOfWeek.getDisplayName(java.time.format.TextStyle.SHORT, locale)
            val timeStr = "${ldt.monthValue}/${ldt.dayOfMonth}($dow) %02d:%02d".format(ldt.hour, ldt.minute)
            if (ldt.isBefore(now)) {
                "$timeStr にリセット済み"
            } else {
                "$timeStr にリセット"
            }
        } else {
            val ld = java.time.LocalDate.parse(resetStr)
            val today = java.time.LocalDate.now()
            val dow = ld.dayOfWeek.getDisplayName(java.time.format.TextStyle.SHORT, locale)
            val dateStr = "${ld.monthValue}/${ld.dayOfMonth}($dow)"
            if (ld.isBefore(today)) {
                "$dateStr にリセット済み"
            } else {
                "$dateStr にリセット"
            }
        }
    } catch (_: Exception) {
        resetStr
    }
}

@Composable
fun AgentsScreen(
    viewModel: AgentsViewModel = viewModel()
) {
    val context = LocalContext.current
    val panes by viewModel.panes.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val rateLimitLoading by viewModel.rateLimitLoading.collectAsState()
    val rateLimitResult by viewModel.rateLimitResult.collectAsState()

    var selectedPaneIndex by remember { mutableStateOf<Int?>(null) }
    var showRateLimitDialog by remember { mutableStateOf(false) }

    // Derive selected pane from live data so it auto-updates
    val selectedPane = selectedPaneIndex?.let { idx -> panes.find { it.index == idx } }

    LaunchedEffect(Unit) {
        val prefs = context.getSharedPreferences(PrefsKeys.PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val host = prefs.getString(PrefsKeys.SSH_HOST, Defaults.SSH_HOST) ?: Defaults.SSH_HOST
        val port = prefs.getString(PrefsKeys.SSH_PORT, Defaults.SSH_PORT_STR)?.toIntOrNull() ?: Defaults.SSH_PORT
        val user = prefs.getString(PrefsKeys.SSH_USER, "") ?: ""
        val keyPath = prefs.getString(PrefsKeys.SSH_KEY_PATH, "") ?: ""
        val password = prefs.getString(PrefsKeys.SSH_PASSWORD, "") ?: ""
        viewModel.connect(host, port, user, keyPath, password)
    }

    // Pause refresh when app is in background
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> viewModel.resumeRefresh()
                Lifecycle.Event.ON_PAUSE -> viewModel.pauseRefresh()
                else -> {}
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    if (selectedPane != null) {
        // Full screen pane detail — always reads from live panes list
        PaneFullScreen(
            pane = selectedPane,
            onBack = { selectedPaneIndex = null },
            onSendCommand = { cmd ->
                viewModel.sendCommandToPane(selectedPane.index, cmd)
            },
            onRefresh = { viewModel.refreshAllPanes() }
        )
    } else {
        // Grid view
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Shikkoku)
        ) {
            Image(
                painter = painterResource(R.drawable.bg_agents),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                alpha = 0.55f,
                modifier = Modifier.fillMaxSize()
            )
            Column(modifier = Modifier.fillMaxSize()) {
                if (errorMessage != null) {
                    SelectionContainer {
                        Text(
                            text = "エラー: $errorMessage",
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.padding(8.dp)
                        )
                    }
                }

                LazyVerticalGrid(
                    columns = GridCells.Fixed(2),
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentPadding = PaddingValues(start = 8.dp, end = 8.dp, top = 8.dp, bottom = 72.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(panes) { pane ->
                        PaneCard(
                            pane = pane,
                            onClick = { selectedPaneIndex = pane.index }
                        )
                    }
                }
            }

            // Rate limit check button (bottom-right)
            FloatingActionButton(
                onClick = {
                    showRateLimitDialog = true
                    viewModel.execRateLimitCheck()
                },
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(16.dp)
                    .size(48.dp),
                containerColor = Sumi,
                contentColor = Kinpaku
            ) {
                Icon(
                    imageVector = Icons.Default.Speed,
                    contentDescription = "使用量",
                    modifier = Modifier.size(24.dp)
                )
            }
        }

        // Rate limit dialog
        if (showRateLimitDialog) {
            var showRawText by remember { mutableStateOf(false) }
            AlertDialog(
                onDismissRequest = {
                    showRateLimitDialog = false
                    viewModel.clearRateLimitResult()
                },
                title = {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        SelectionContainer {
                            Text("Rate Limit Check", color = Kinpaku)
                        }
                        if (!rateLimitLoading && rateLimitResult != null) {
                            TextButton(onClick = { showRawText = !showRawText }) {
                                Text(if (showRawText) "UI" else "Raw", color = Color(0xFF888888), fontSize = 11.sp)
                            }
                        }
                    }
                },
                text = {
                    if (rateLimitLoading) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 16.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator(color = Kinpaku)
                        }
                    } else if (showRawText) {
                        SelectionContainer {
                            Text(
                                text = rateLimitResult ?: "",
                                color = Zouge,
                                fontSize = 10.sp,
                                fontFamily = FontFamily.Monospace,
                                modifier = Modifier.verticalScroll(rememberScrollState())
                            )
                        }
                    } else {
                        RateLimitContent(rawText = rateLimitResult ?: "")
                    }
                },
                confirmButton = {
                    TextButton(onClick = {
                        showRateLimitDialog = false
                        viewModel.clearRateLimitResult()
                    }) {
                        SelectionContainer {
                            Text("閉じる", color = Kinpaku)
                        }
                    }
                },
                containerColor = Sumi,
                titleContentColor = Kinpaku,
                textContentColor = Zouge
            )
        }
    }
}

@Composable
fun PaneCard(
    pane: PaneInfo,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(160.dp)
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = Color(0x802D2D2D))
    ) {
        SelectionContainer {
            Column(modifier = Modifier.padding(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = pane.agentId.ifBlank { "pane${pane.index}" },
                        color = Kinpaku,
                        fontSize = 12.sp,
                        fontFamily = FontFamily.Monospace
                    )
                    if (pane.modelName.isNotBlank()) {
                        Text(
                            text = " (${pane.modelName})",
                            color = Color(0xFFAAAAAA),
                            fontSize = 10.sp,
                            fontFamily = FontFamily.Monospace
                        )
                    }
                }
                Spacer(modifier = Modifier.height(4.dp))
                val tailLines = remember(pane.content) {
                    pane.content.lines().dropLastWhile { it.isBlank() }.takeLast(10).joinToString("\n")
                }
                Text(
                    text = parseAnsiColors(tailLines),
                    color = Zouge,
                    fontSize = 10.sp,
                    fontFamily = FontFamily.Monospace,
                    maxLines = 10,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@Composable
fun PaneFullScreen(
    pane: PaneInfo,
    onBack: () -> Unit,
    onSendCommand: (String) -> Unit,
    onRefresh: () -> Unit
) {
    val context = LocalContext.current
    var commandTextValue by remember { mutableStateOf(TextFieldValue("")) }
    var isListening by remember { mutableStateOf(false) }
    val speechRecognizer = remember {
        if (SpeechRecognizer.isRecognitionAvailable(context))
            SpeechRecognizer.createSpeechRecognizer(context)
        else null
    }
    val horizontalScrollState = rememberScrollState()
    val verticalScrollState = rememberScrollState()
    val parsedPaneContent = remember(pane.content) { parseAnsiColors(pane.content) }

    DisposableEffect(Unit) {
        onDispose { speechRecognizer?.destroy() }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted && speechRecognizer != null) {
            startContinuousListening(speechRecognizer, { isListening }) { result ->
                val newText = if (commandTextValue.text.isEmpty()) result else "${commandTextValue.text} $result"
                commandTextValue = TextFieldValue(text = newText, selection = TextRange(newText.length))
            }
            isListening = true
        }
    }

    // Keep following the newest output while preserving text-selection support.
    LaunchedEffect(pane.content, verticalScrollState.maxValue) {
        verticalScrollState.scrollTo(verticalScrollState.maxValue)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Shikkoku)
    ) {
        Image(
            painter = painterResource(R.drawable.bg_agents),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            alpha = 0.55f,
            modifier = Modifier.fillMaxSize()
        )
    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        // Top bar with agent name and back button
                Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color(0x802D2D2D))
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.Default.ArrowBack,
                    contentDescription = "戻る",
                    tint = Kinpaku
                )
            }
            SelectionContainer {
                Row(
                    modifier = Modifier.weight(1f),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = pane.agentId.ifBlank { "pane${pane.index}" },
                        color = Kinpaku,
                        fontSize = 16.sp,
                        fontFamily = FontFamily.Monospace
                    )
                    if (pane.modelName.isNotBlank()) {
                        Text(
                            text = " (${pane.modelName})",
                            color = Color(0xFFAAAAAA),
                            fontSize = 12.sp,
                            fontFamily = FontFamily.Monospace
                        )
                    }
                }
            }
        }

        // Full screen pane content
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .horizontalScroll(horizontalScrollState)
        ) {
            SelectionContainer {
                Text(
                    text = parsedPaneContent,
                    color = Zouge,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp,
                    softWrap = false,
                    modifier = Modifier
                        .fillMaxHeight()
                        .verticalScroll(verticalScrollState)
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }
        } // Box (horizontal scroll)

        // Special keys bar
        SpecialKeysRow(onSendKey = { onSendCommand(it) })

        // Command input at bottom
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = commandTextValue,
                onValueChange = { commandTextValue = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("コマンドを入力") },
                singleLine = true
            )
            Spacer(modifier = Modifier.width(4.dp))
            // Voice input button
            IconButton(
                onClick = {
                    if (speechRecognizer == null) return@IconButton
                    if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
                        == PackageManager.PERMISSION_GRANTED
                    ) {
                        if (isListening) {
                            speechRecognizer.cancel()
                            isListening = false
                        } else {
                            startContinuousListening(speechRecognizer, { isListening }) { result ->
                                val newText = if (commandTextValue.text.isEmpty()) result else "${commandTextValue.text} $result"
                                commandTextValue = TextFieldValue(text = newText, selection = TextRange(newText.length))
                            }
                            isListening = true
                        }
                    } else {
                        permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                    }
                }
            ) {
                Icon(
                    imageVector = Icons.Default.Mic,
                    contentDescription = "音声入力",
                    tint = if (isListening) Kurenai else Kinpaku
                )
            }
            Spacer(modifier = Modifier.width(4.dp))
            IconButton(
                onClick = {
                    if (commandTextValue.text.isNotBlank()) {
                        onSendCommand(commandTextValue.text)
                        commandTextValue = TextFieldValue("")
                    }
                },
                enabled = commandTextValue.text.isNotBlank() && !isListening
            ) {
                Icon(
                    imageVector = Icons.Default.Send,
                    contentDescription = "送信",
                    tint = if (commandTextValue.text.isNotBlank() && !isListening) Kinpaku else TextMuted
                )
            }
        }
    } // Column
    } // Box
}

// ── Rate Limit UI ─────────────────────────────────────────────────────────────
@Composable
private fun RateLimitContent(rawText: String) {
    val data = remember(rawText) { parseRateLimitResult(rawText) }
    val claudeMax = data.claudeMax
    val codexQuota = data.codexQuota
    val codexEntries = data.codexEntries
    val hasAnyData = claudeMax.window5h != null || claudeMax.window7d != null ||
        codexQuota.account5h != null || codexQuota.model5h != null || codexEntries.isNotEmpty()
    SelectionContainer {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            if (!hasAnyData && rawText.isNotBlank()) {
                Text("パース失敗 — Raw出力:", color = Color(0xFFCC4444), fontSize = 11.sp)
                Text(rawText, color = Zouge, fontSize = 10.sp, fontFamily = FontFamily.Monospace)
            }

            // ── Claude Max section ──
            Text("Claude Max", color = Kinpaku, fontSize = 13.sp, fontFamily = FontFamily.Monospace)
            Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(Color(0xFF555555)))

            claudeMax.window5h?.let { w ->
                val color = rateLimitBarColor(w.percent)
                Text("5時間枠", color = Zouge, fontSize = 12.sp)
                LinearProgressIndicator(
                    progress = { w.percent / 100f },
                    modifier = Modifier.fillMaxWidth(),
                    color = color,
                    trackColor = Color(0xFF444444)
                )
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("${w.percent}%", color = color, fontSize = 11.sp)
                    Text(formatResetTime(w.resetStr), color = Color(0xFF888888), fontSize = 11.sp)
                }
            }

        claudeMax.window7d?.let { w ->
            val color = rateLimitBarColor(w.percent)
            Text("7日枠", color = Zouge, fontSize = 12.sp)
            LinearProgressIndicator(
                progress = { w.percent / 100f },
                modifier = Modifier.fillMaxWidth(),
                color = color,
                trackColor = Color(0xFF444444)
            )
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("${w.percent}%", color = color, fontSize = 11.sp)
                Text(formatResetTime(w.resetStr), color = Color(0xFF888888), fontSize = 11.sp)
            }
            if (claudeMax.sonnet7d != null || claudeMax.opus7d != null) {
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    claudeMax.sonnet7d?.let { Text("Sonnet: ${it}%", color = Color(0xFF888888), fontSize = 11.sp) }
                    claudeMax.opus7d?.let   { Text("Opus: ${it}%",   color = Color(0xFF888888), fontSize = 11.sp) }
                }
            }
        }

        claudeMax.todayTokens?.let { tokens ->
            Text("本日トークン", color = Zouge, fontSize = 12.sp)
            Text(tokens, color = Kinpaku, fontSize = 15.sp, fontFamily = FontFamily.Monospace)
        }

        if (claudeMax.sessions != null || claudeMax.messages != null) {
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                claudeMax.sessions?.let { Text("セッション: $it", color = Color(0xFF888888), fontSize = 11.sp) }
                claudeMax.messages?.let { Text("メッセージ: $it", color = Color(0xFF888888), fontSize = 11.sp) }
            }
        }

        // ── Codex Quota section ──
        if (codexQuota.account5h != null || codexQuota.model5h != null) {
            Spacer(modifier = Modifier.height(4.dp))
            Text("ChatGPT Pro クォータ", color = Kinpaku, fontSize = 13.sp, fontFamily = FontFamily.Monospace)
            Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(Color(0xFF555555)))

            // Account-level quota
            codexQuota.account5h?.let { w ->
                val color = rateLimitBarColor(w.percent)
                Text("Account 5時間枠", color = Zouge, fontSize = 12.sp)
                LinearProgressIndicator(
                    progress = { w.percent / 100f },
                    modifier = Modifier.fillMaxWidth(),
                    color = color,
                    trackColor = Color(0xFF444444)
                )
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("${w.percent.toInt()}% used", color = color, fontSize = 11.sp)
                    Text("resets ${w.resetStr}", color = Color(0xFF888888), fontSize = 11.sp)
                }
            }
            codexQuota.account7d?.let { w ->
                val color = rateLimitBarColor(w.percent)
                Text("Account Weekly", color = Zouge, fontSize = 12.sp)
                LinearProgressIndicator(
                    progress = { w.percent / 100f },
                    modifier = Modifier.fillMaxWidth(),
                    color = color,
                    trackColor = Color(0xFF444444)
                )
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("${w.percent.toInt()}% used", color = color, fontSize = 11.sp)
                    Text("resets ${w.resetStr}", color = Color(0xFF888888), fontSize = 11.sp)
                }
            }

            // Model-level quota
            if (codexQuota.model5h != null) {
                val label = codexQuota.modelName ?: "Model"
                codexQuota.model5h.let { w ->
                    val color = rateLimitBarColor(w.percent)
                    Text("$label 5時間枠", color = Zouge, fontSize = 12.sp)
                    LinearProgressIndicator(
                        progress = { w.percent / 100f },
                        modifier = Modifier.fillMaxWidth(),
                        color = color,
                        trackColor = Color(0xFF444444)
                    )
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("${w.percent.toInt()}% used", color = color, fontSize = 11.sp)
                        Text("resets ${w.resetStr}", color = Color(0xFF888888), fontSize = 11.sp)
                    }
                }
                codexQuota.model7d?.let { w ->
                    val color = rateLimitBarColor(w.percent)
                    Text("$label Weekly", color = Zouge, fontSize = 12.sp)
                    LinearProgressIndicator(
                        progress = { w.percent / 100f },
                        modifier = Modifier.fillMaxWidth(),
                        color = color,
                        trackColor = Color(0xFF444444)
                    )
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("${w.percent.toInt()}% used", color = color, fontSize = 11.sp)
                        Text("resets ${w.resetStr}", color = Color(0xFF888888), fontSize = 11.sp)
                    }
                }
            }
        }

        // ── Codex context per agent ──
        if (codexEntries.isNotEmpty()) {
            Spacer(modifier = Modifier.height(4.dp))
            Text("Codex5.3 コンテキスト", color = Kinpaku, fontSize = 13.sp, fontFamily = FontFamily.Monospace)
            Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(Color(0xFF555555)))

            codexEntries.forEach { entry ->
                val label = "ash${entry.ashigaru}"
                val pct = entry.percent
                if (pct != null) {
                    val usedPct = 100f - pct
                    val color = rateLimitBarColor(usedPct)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(label, color = Zouge, fontSize = 11.sp, modifier = Modifier.width(40.dp))
                        LinearProgressIndicator(
                            progress = { usedPct / 100f },
                            modifier = Modifier.weight(1f),
                            color = color,
                            trackColor = Color(0xFF444444)
                        )
                        Text("${pct.toInt()}%", color = color, fontSize = 11.sp)
                    }
                } else {
                    Row(modifier = Modifier.fillMaxWidth()) {
                        Text("$label: ?", color = Color(0xFF888888), fontSize = 11.sp)
                    }
                }
            }
        }
        }
    }
}
