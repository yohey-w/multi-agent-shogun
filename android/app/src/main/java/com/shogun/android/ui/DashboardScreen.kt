package com.shogun.android.ui

import android.webkit.WebView
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.ui.graphics.Color
import com.shogun.android.ui.theme.*
import com.shogun.android.util.Defaults
import com.shogun.android.util.PrefsKeys
import androidx.compose.ui.layout.ContentScale
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.viewmodel.compose.viewModel
import com.shogun.android.R
import com.shogun.android.viewmodel.DashboardViewModel
import org.commonmark.ext.gfm.tables.TablesExtension
import org.commonmark.parser.Parser
import org.commonmark.renderer.html.HtmlRenderer

@Composable
fun DashboardScreen(
    viewModel: DashboardViewModel = viewModel()
) {
    val context = LocalContext.current
    val markdownContent by viewModel.markdownContent.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()

    val htmlContent = remember(markdownContent) {
        if (markdownContent.isBlank()) "" else markdownToHtml(markdownContent)
    }

    LaunchedEffect(Unit) {
        val prefs = context.getSharedPreferences(PrefsKeys.PREFS_NAME, android.content.Context.MODE_PRIVATE)
        val host = prefs.getString(PrefsKeys.SSH_HOST, Defaults.SSH_HOST) ?: Defaults.SSH_HOST
        val port = prefs.getString(PrefsKeys.SSH_PORT, Defaults.SSH_PORT_STR)?.toIntOrNull() ?: Defaults.SSH_PORT
        val user = prefs.getString(PrefsKeys.SSH_USER, "") ?: ""
        val keyPath = prefs.getString(PrefsKeys.SSH_KEY_PATH, "") ?: ""
        val password = prefs.getString(PrefsKeys.SSH_PASSWORD, "") ?: ""
        viewModel.connect(host, port, user, keyPath, password)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Shikkoku)
    ) {
        Image(
            painter = painterResource(R.drawable.bg_castle),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            alpha = 0.55f,
            modifier = Modifier.fillMaxSize()
        )
        if (errorMessage != null) {
            Box(
                modifier = Modifier.fillMaxSize().padding(16.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "エラー: $errorMessage",
                    color = MaterialTheme.colorScheme.error
                )
            }
        } else if (markdownContent.isBlank() && !isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text("読み込み中…", color = Zouge)
            }
        } else {
            AndroidView(
                factory = { ctx ->
                    WebView(ctx).apply {
                        setBackgroundColor(android.graphics.Color.TRANSPARENT)
                        settings.javaScriptEnabled = false
                        settings.allowContentAccess = true
                        settings.allowFileAccess = true
                        settings.domStorageEnabled = true
                        settings.setSupportMultipleWindows(true)
                        isFocusable = true
                        isFocusableInTouchMode = true
                        isLongClickable = true
                        setOnLongClickListener { false }
                        setOnTouchListener { _, _ -> false }
                    }
                },
                update = { webView ->
                    if (htmlContent.isNotBlank()) {
                        val fullHtml = buildDashboardHtml(htmlContent)
                        webView.loadDataWithBaseURL(null, fullHtml, "text/html", "UTF-8", null)
                    }
                },
                modifier = Modifier.fillMaxSize()
            )
        }
    } // Box
}

private fun markdownToHtml(markdown: String): String {
    val extensions = listOf(TablesExtension.create())
    val parser = Parser.builder().extensions(extensions).build()
    val renderer = HtmlRenderer.builder().extensions(extensions).build()
    val document = parser.parse(markdown)
    return renderer.render(document)
}

private fun buildDashboardHtml(bodyHtml: String): String = """
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body {
    color: #E8DCC8;
    background: transparent;
    -webkit-user-select: text !important;
    -webkit-touch-callout: default;
    font-family: -apple-system, sans-serif;
    user-select: text !important;
    font-size: 14px;
    padding: 16px;
    margin: 0;
    -webkit-text-size-adjust: 100%;
}
* {
    -webkit-user-select: text !important;
    user-select: text !important;
}
h1, h2, h3, h4 { color: #C9A94E; margin-top: 16px; margin-bottom: 8px; }
h1 { font-size: 20px; }
h2 { font-size: 17px; }
h3 { font-size: 15px; }
table { border-collapse: collapse; width: 100%; margin: 8px 0; }
th, td { border: 1px solid #555; padding: 6px 8px; text-align: left; }
th { background-color: rgba(60,60,60,0.8); color: #C9A94E; }
tr:nth-child(even) { background-color: rgba(45,45,45,0.5); }
a { color: #D4B96A; }
code { background-color: #333; padding: 1px 4px; border-radius: 3px; font-size: 13px; }
pre { background-color: #222; padding: 8px; border-radius: 4px; overflow-x: auto; }
pre code { background: none; padding: 0; }
ul, ol { padding-left: 20px; }
li { margin-bottom: 4px; }
hr { border: none; border-top: 1px solid #555; margin: 12px 0; }
::selection { background: #C9A94E; color: #1A1A1A; }
</style>
</head>
<body>$bodyHtml</body></html>
""".trimIndent()
