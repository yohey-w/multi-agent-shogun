package com.shogun.android.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val ShogunColorScheme = darkColorScheme(
    // Primary — Kinpaku gold (accents, active tabs, headings)
    primary             = Kinpaku,
    onPrimary           = Shikkoku,
    primaryContainer    = Surface2,
    onPrimaryContainer  = Zouge,

    // Secondary — Shuaka red (actions, CTA, destructive)
    secondary              = Shuaka,
    onSecondary            = Zouge,
    secondaryContainer     = Surface1,
    onSecondaryContainer   = Zouge,

    // Tertiary — Matsuba green (success, connected)
    tertiary              = Matsuba,
    onTertiary            = Zouge,
    tertiaryContainer     = Surface1,
    onTertiaryContainer   = Zouge,

    // Error — Kurenai red (error, disconnected)
    error             = Kurenai,
    onError           = Zouge,
    errorContainer    = Surface2,
    onErrorContainer  = Kurenai,

    // Background — Shikkoku base
    background   = Shikkoku,
    onBackground = TextSecondary,

    // Surface — Sumi elevated card
    surface          = Sumi,
    onSurface        = TextSecondary,
    surfaceVariant   = Surface2,
    onSurfaceVariant = TextTertiary,

    // Borders
    outline        = BorderStandard,
    outlineVariant = BorderEmphasis,

    // Other
    scrim            = Shikkoku,
    inverseSurface   = Zouge,
    inverseOnSurface = Shikkoku,
    inversePrimary   = Sumi,
)

@Composable
fun ShogunTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = ShogunColorScheme,
        content = content,
    )
}
