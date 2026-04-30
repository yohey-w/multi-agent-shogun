package com.shogun.android.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.shogun.android.ui.theme.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.shogun.android.viewmodel.SettingsViewModel

@Composable
fun NtfySettingsSection(viewModel: SettingsViewModel) {
    val notificationEnabled by viewModel.notificationEnabled.collectAsState()
    val ntfyTopic by viewModel.ntfyTopic.collectAsState()
    val notifyCmdComplete by viewModel.notifyCmdComplete.collectAsState()
    val notifyCmdFailure by viewModel.notifyCmdFailure.collectAsState()
    val notifyActionRequired by viewModel.notifyActionRequired.collectAsState()
    val notifyDashboardUpdate by viewModel.notifyDashboardUpdate.collectAsState()
    val notifyStreakUpdate by viewModel.notifyStreakUpdate.collectAsState()
    val notifyAgentResponse by viewModel.notifyAgentResponse.collectAsState()

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            "通知設定",
            style = MaterialTheme.typography.titleMedium,
            color = Kinpaku,
            fontWeight = FontWeight.Bold
        )

        // Master toggle
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text("通知を有効にする", color = Zouge)
            Switch(
                checked = notificationEnabled,
                onCheckedChange = { viewModel.setNotificationEnabled(it) },
                colors = SwitchDefaults.colors(
                    checkedThumbColor = Color.White,
                    checkedTrackColor = Shuaka,
                    uncheckedThumbColor = Color.White,
                    uncheckedTrackColor = TextMuted
                )
            )
        }

        // ntfy topic field
        OutlinedTextField(
            value = ntfyTopic,
            onValueChange = { viewModel.setNtfyTopic(it) },
            label = { Text("ntfyトピック", color = TextTertiary) },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Zouge,
                unfocusedTextColor = Zouge,
                focusedContainerColor = Surface4,
                unfocusedContainerColor = Surface4,
                focusedBorderColor = BorderFocus,
                unfocusedBorderColor = BorderStandard
            )
        )

        Text(
            "カテゴリ別通知（マスタースイッチON時のみ有効）",
            style = MaterialTheme.typography.bodySmall,
            color = TextTertiary
        )

        NtfyCategoryToggle(
            label = "✅ タスク完了",
            checked = notifyCmdComplete,
            onCheckedChange = { viewModel.setNotifyCmdComplete(it) },
            enabled = notificationEnabled
        )
        NtfyCategoryToggle(
            label = "❌ タスク失敗",
            checked = notifyCmdFailure,
            onCheckedChange = { viewModel.setNotifyCmdFailure(it) },
            enabled = notificationEnabled
        )
        NtfyCategoryToggle(
            label = "🚨 要対応",
            checked = notifyActionRequired,
            onCheckedChange = { viewModel.setNotifyActionRequired(it) },
            enabled = notificationEnabled
        )
        NtfyCategoryToggle(
            label = "📊 ダッシュボード更新",
            checked = notifyDashboardUpdate,
            onCheckedChange = { viewModel.setNotifyDashboardUpdate(it) },
            enabled = notificationEnabled
        )
        NtfyCategoryToggle(
            label = "🔥 ストリーク更新",
            checked = notifyStreakUpdate,
            onCheckedChange = { viewModel.setNotifyStreakUpdate(it) },
            enabled = notificationEnabled
        )
        NtfyCategoryToggle(
            label = "💬 エージェント応答",
            checked = notifyAgentResponse,
            onCheckedChange = { viewModel.setNotifyAgentResponse(it) },
            enabled = notificationEnabled
        )
    }
}

@Composable
private fun NtfyCategoryToggle(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    enabled: Boolean
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            label,
            color = if (enabled) Zouge else TextMuted
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            enabled = enabled,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = Shuaka,
                uncheckedThumbColor = Color.White,
                uncheckedTrackColor = TextMuted,
                disabledCheckedThumbColor = Color(0xFF999999),
                disabledCheckedTrackColor = Color(0xFF555555),
                disabledUncheckedThumbColor = Color(0xFF999999),
                disabledUncheckedTrackColor = Color(0xFF555555)
            )
        )
    }
}
