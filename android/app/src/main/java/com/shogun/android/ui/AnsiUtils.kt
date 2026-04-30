package com.shogun.android.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle

private val ANSI_COLOR_RE = Regex("\u001B\\[([0-9;]*)m")
private val ANSI_ESCAPE_RE = Regex("\u001B(?:\\[[0-9;]*[A-Za-z]|[^\\[])")

// Standard 8-color palette (codes 0-7 in 256-color, or 30-37 basic)
private val STANDARD_COLORS = arrayOf(
    Color(0xFF000000), // 0 black
    Color(0xFFCC4444), // 1 red
    Color(0xFF66BB6A), // 2 green
    Color(0xFFFFEB3B), // 3 yellow
    Color(0xFF42A5F5), // 4 blue
    Color(0xFFAB47BC), // 5 magenta
    Color(0xFF26C6DA), // 6 cyan
    Color(0xFFE0E0E0), // 7 white
)

// Bright 8-color palette (codes 8-15 in 256-color, or 90-97 basic)
private val BRIGHT_COLORS = arrayOf(
    Color(0xFF757575), // 8  bright black (gray)
    Color(0xFFFF5252), // 9  bright red
    Color(0xFF69F0AE), // 10 bright green
    Color(0xFFFFD740), // 11 bright yellow
    Color(0xFF448AFF), // 12 bright blue
    Color(0xFFE040FB), // 13 bright magenta
    Color(0xFF18FFFF), // 14 bright cyan
    Color.White,       // 15 bright white
)

/**
 * Convert 256-color code (0-255) to Compose Color.
 * 0-7: standard, 8-15: bright, 16-231: 6x6x6 RGB cube, 232-255: grayscale
 */
private fun color256(n: Int): Color? = when {
    n in 0..7 -> STANDARD_COLORS[n]
    n in 8..15 -> BRIGHT_COLORS[n - 8]
    n in 16..231 -> {
        val idx = n - 16
        val r = (idx / 36) * 51
        val g = ((idx % 36) / 6) * 51
        val b = (idx % 6) * 51
        Color(0xFF000000 or (r.toLong() shl 16) or (g.toLong() shl 8) or b.toLong())
    }
    n in 232..255 -> {
        val gray = 8 + (n - 232) * 10
        Color(0xFF000000 or (gray.toLong() shl 16) or (gray.toLong() shl 8) or gray.toLong())
    }
    else -> null
}

fun parseAnsiColors(text: String): AnnotatedString = buildAnnotatedString {
    var currentColor: Color? = null
    var isBold = false
    var pos = 0

    fun appendChunk(s: String) {
        val clean = ANSI_ESCAPE_RE.replace(s, "")
        if (clean.isEmpty()) return
        val style = SpanStyle(
            color = currentColor ?: Color.Unspecified,
            fontWeight = if (isBold) FontWeight.Bold else null
        )
        if (currentColor != null || isBold) {
            withStyle(style) { append(clean) }
        } else {
            append(clean)
        }
    }

    for (match in ANSI_COLOR_RE.findAll(text)) {
        appendChunk(text.substring(pos, match.range.first))
        val codesStr = match.groupValues[1]
        if (codesStr.isEmpty()) {
            currentColor = null
            isBold = false
        } else {
            val codes = codesStr.split(";").mapNotNull { it.toIntOrNull() }
            var i = 0
            while (i < codes.size) {
                when (codes[i]) {
                    0 -> { currentColor = null; isBold = false }
                    1 -> isBold = true
                    2 -> isBold = false // dim
                    22 -> isBold = false // normal intensity
                    // Basic foreground colors 30-37
                    in 30..37 -> currentColor = STANDARD_COLORS[codes[i] - 30]
                    // Default foreground
                    39 -> currentColor = null
                    // Basic background colors 40-47 (ignore for text display)
                    in 40..47 -> { /* skip */ }
                    49 -> { /* default background, skip */ }
                    // Bright foreground colors 90-97
                    in 90..97 -> currentColor = BRIGHT_COLORS[codes[i] - 90]
                    // Bright background colors 100-107 (ignore)
                    in 100..107 -> { /* skip */ }
                    // Extended color: 38;5;N (256-color fg) or 38;2;R;G;B (truecolor fg)
                    38 -> {
                        if (i + 1 < codes.size) {
                            when (codes[i + 1]) {
                                5 -> { // 256-color: 38;5;N
                                    if (i + 2 < codes.size) {
                                        currentColor = color256(codes[i + 2])
                                        i += 2
                                    }
                                }
                                2 -> { // Truecolor: 38;2;R;G;B
                                    if (i + 4 < codes.size) {
                                        val r = codes[i + 2].coerceIn(0, 255)
                                        val g = codes[i + 3].coerceIn(0, 255)
                                        val b = codes[i + 4].coerceIn(0, 255)
                                        currentColor = Color(
                                            0xFF000000 or (r.toLong() shl 16) or (g.toLong() shl 8) or b.toLong()
                                        )
                                        i += 4
                                    }
                                }
                            }
                        }
                    }
                    // Extended background: 48;5;N or 48;2;R;G;B (skip)
                    48 -> {
                        if (i + 1 < codes.size) {
                            when (codes[i + 1]) {
                                5 -> i += 2 // skip 48;5;N
                                2 -> i += 4 // skip 48;2;R;G;B
                            }
                        }
                    }
                }
                i++
            }
        }
        pos = match.range.last + 1
    }
    appendChunk(text.substring(pos))
}
