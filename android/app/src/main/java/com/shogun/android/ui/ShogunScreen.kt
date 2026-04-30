package com.shogun.android.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.VolumeOff
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.shogun.android.ui.theme.*
import com.shogun.android.util.Defaults
import com.shogun.android.util.PrefsKeys
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.shogun.android.R
import com.shogun.android.viewmodel.ShogunViewModel

@Composable
fun ShogunScreen(
    viewModel: ShogunViewModel = viewModel(),
    mediaPlayer: MediaPlayer? = null,
    isBgmPlaying: Boolean = false,
    bgmTrackLabel: String = "",
    onBgmToggle: () -> Unit = {}
) {
    val context = LocalContext.current
    val paneContent by viewModel.paneContent.collectAsState()
    val isConnected by viewModel.isConnected.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()

    var inputTextValue by remember { mutableStateOf(TextFieldValue("")) }
    var isListening by remember { mutableStateOf(false) }
    var isInputExpanded by remember { mutableStateOf(false) }

    // Duck BGM while voice input is active
    LaunchedEffect(isListening) {
        if (isListening) {
            mediaPlayer?.setVolume(0.05f, 0.05f)
        } else {
            mediaPlayer?.setVolume(1.0f, 1.0f)
        }
    }

    val listState = rememberLazyListState()
    val lines = remember(paneContent) { paneContent.lines() }

    val speechRecognizer = remember {
        if (SpeechRecognizer.isRecognitionAvailable(context))
            SpeechRecognizer.createSpeechRecognizer(context)
        else null
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted && speechRecognizer != null) {
            startContinuousListening(speechRecognizer, { isListening }) { result ->
                val newText = if (inputTextValue.text.isEmpty()) result else "${inputTextValue.text} $result"
                inputTextValue = TextFieldValue(text = newText, selection = TextRange(newText.length))
            }
            isListening = true
        }
    }

    // Auto-connect on composition
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
                Lifecycle.Event.ON_RESUME -> {
                    viewModel.resumeRefresh()
                    if (isListening && speechRecognizer != null) {
                        startContinuousListening(speechRecognizer, { isListening }) { result ->
                            val newText = if (inputTextValue.text.isEmpty()) result else "${inputTextValue.text} $result"
                            inputTextValue = TextFieldValue(text = newText, selection = TextRange(newText.length))
                        }
                    }
                }
                Lifecycle.Event.ON_PAUSE -> {
                    viewModel.pauseRefresh()
                    speechRecognizer?.cancel()
                }
                else -> {}
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Auto-scroll to bottom when content changes
    LaunchedEffect(lines.size) {
        if (lines.isNotEmpty()) {
            listState.scrollToItem(lines.size - 1)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Shikkoku)
    ) {
        Image(
            painter = painterResource(R.drawable.bg_shogun),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            alpha = 0.55f,
            modifier = Modifier.fillMaxSize()
        )
        Column(modifier = Modifier.fillMaxSize()) {
        // 陣幕バー — connection status
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(if (isConnected) Matsuba else Kurenai)
                .padding(4.dp),
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                text = if (isConnected) "接続中 — 将軍セッション" else "未接続",
                color = Zouge,
                fontSize = 12.sp
            )
        }

        // Pane content display with LazyColumn
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
        ) {
            if (errorMessage != null) {
                Text(
                    text = "エラー: $errorMessage",
                    color = Kurenai,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(8.dp)
                )
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .fillMaxHeight()
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    items(lines) { line ->
                        SelectionContainer {
                            Text(
                                text = parseAnsiColors(line),
                                color = Zouge,
                                fontFamily = FontFamily.Monospace,
                                fontSize = 13.sp,
                                softWrap = false
                            )
                        }
                    }
                }
            }
        }

        // Special keys bar
        SpecialKeysRow(onSendKey = { viewModel.sendCommand(it) })

        // Input area
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp)
        ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = inputTextValue,
                onValueChange = { inputTextValue = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("コマンドを入力", color = TextMuted) },
                singleLine = !isInputExpanded,
                maxLines = if (isInputExpanded) 6 else 1,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = Zouge,
                    unfocusedTextColor = Zouge,
                    focusedBorderColor = BorderFocus,
                    unfocusedBorderColor = BorderStandard,
                    cursorColor = Kinpaku,
                    focusedContainerColor = Surface4,
                    unfocusedContainerColor = Surface4,
                )
            )

            // Expand/collapse text button
            IconButton(
                onClick = { isInputExpanded = !isInputExpanded },
                modifier = Modifier.size(36.dp)
            ) {
                Icon(
                    imageVector = if (isInputExpanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                    contentDescription = "展開",
                    tint = Kinpaku
                )
            }
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // BGM toggle button — cycles through 3 tracks + OFF
            IconButton(onClick = onBgmToggle) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = if (isBgmPlaying) Icons.Default.VolumeUp else Icons.Default.VolumeOff,
                        contentDescription = "BGM",
                        tint = if (isBgmPlaying) Kinpaku else TextMuted
                    )
                    if (isBgmPlaying && bgmTrackLabel.isNotEmpty()) {
                        Text(
                            text = bgmTrackLabel,
                            color = Kinpaku,
                            fontSize = 8.sp
                        )
                    }
                }
            }

            // Voice input button (manual ON/OFF — stays on until user taps again)
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
                                val newText = if (inputTextValue.text.isEmpty()) result else "${inputTextValue.text} $result"
                                inputTextValue = TextFieldValue(text = newText, selection = TextRange(newText.length))
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

            // Send button
            IconButton(
                onClick = {
                    if (inputTextValue.text.isNotBlank()) {
                        viewModel.sendCommand(inputTextValue.text)
                        inputTextValue = TextFieldValue("")
                    }
                },
                enabled = inputTextValue.text.isNotBlank() && isConnected && !isListening
            ) {
                Icon(
                    imageVector = Icons.Default.Send,
                    contentDescription = "送信",
                    tint = if (inputTextValue.text.isNotBlank() && isConnected && !isListening) Kinpaku else TextMuted
                )
            }
        } // Row (buttons)
        } // Column (input area)
        } // Column (main)
    } // Box
}

@Composable
fun SpecialKeysRow(onSendKey: (String) -> Unit) {
    // Ordered by usage frequency for tmux + Claude Code workflow
    val specialKeys = listOf(
        "↵" to "\n",        // Enter — most used (confirm commands, send input)
        "C-c" to "\u0003",  // Interrupt — stop running process
        "C-b" to "\u0002",  // tmux prefix — pane control (C-b C-b for background)
        "↑" to "\u001b[A",  // History up
        "↓" to "\u001b[B",  // History down
        "Tab" to "\t",      // Autocomplete
        "ESC" to "\u001b",  // Cancel / exit mode
        "C-o" to "\u000f",  // Accept line in Claude Code
        "C-d" to "\u0004"   // EOF / exit
    )
    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        items(specialKeys) { (label, value) ->
            OutlinedButton(
                onClick = { onSendKey(value) },
                modifier = Modifier.height(32.dp),
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                border = BorderStroke(1.dp, BorderFocus),
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = Surface4,
                    contentColor = Zouge
                )
            ) {
                Text(
                    text = label,
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace
                )
            }
        }
    }
}

/**
 * Continuous listening — auto-restarts after each result.
 * Checks isActive() before restarting to respect user's OFF toggle.
 * Caller should use cancel() (not stopListening()) to stop cleanly.
 */
fun startContinuousListening(
    speechRecognizer: SpeechRecognizer,
    isActive: () -> Boolean,
    onResult: (String) -> Unit
) {
    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ja-JP")
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 5000L)
        putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 5000L)
        putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 2000L)
    }
    speechRecognizer.setRecognitionListener(object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onError(error: Int) {
            if (!isActive()) return
            when (error) {
                SpeechRecognizer.ERROR_AUDIO,
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> {
                    // Fatal — do not restart
                }
                else -> {
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        if (isActive()) {
                            try { speechRecognizer.startListening(intent) } catch (_: Exception) {}
                        }
                    }, 300)
                }
            }
        }
        override fun onResults(results: Bundle?) {
            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if (!matches.isNullOrEmpty()) {
                onResult(matches[0])
            }
            if (isActive()) {
                speechRecognizer.startListening(intent)
            }
        }
        override fun onPartialResults(partialResults: Bundle?) {}
        override fun onEvent(eventType: Int, params: Bundle?) {}
    })
    speechRecognizer.startListening(intent)
}
