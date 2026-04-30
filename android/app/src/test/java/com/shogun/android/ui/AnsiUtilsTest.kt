package com.shogun.android.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for ANSI escape sequence parsing.
 * Tests cover basic 8-color, 256-color, truecolor, bold, and edge cases.
 */
class AnsiUtilsTest {

    // Helper: extract plain text from AnnotatedString
    private fun parseText(input: String): String = parseAnsiColors(input).text

    @Test
    fun `plain text passes through unchanged`() {
        val result = parseAnsiColors("hello world")
        assertEquals("hello world", result.text)
        assertEquals(0, result.spanStyles.size)
    }

    @Test
    fun `empty string returns empty`() {
        val result = parseAnsiColors("")
        assertEquals("", result.text)
    }

    @Test
    fun `basic color codes are stripped from text`() {
        // \u001b[31m = red, \u001b[0m = reset
        val input = "\u001b[31mERROR\u001b[0m ok"
        assertEquals("ERROR ok", parseText(input))
    }

    @Test
    fun `basic red color produces span`() {
        val input = "\u001b[31mERROR\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("ERROR", result.text)
        assertEquals(1, result.spanStyles.size)
        // Red color: 0xFFCC4444
        assertEquals(0xFFCC4444.toInt(), result.spanStyles[0].item.color.value.shr(32).toInt())
    }

    @Test
    fun `basic green color produces span`() {
        val input = "\u001b[32mSUCCESS\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("SUCCESS", result.text)
        assertEquals(1, result.spanStyles.size)
    }

    @Test
    fun `multiple colors in sequence`() {
        val input = "\u001b[31mred\u001b[32mgreen\u001b[0mplain"
        val result = parseAnsiColors(input)
        assertEquals("redgreenplain", result.text)
        assertEquals(2, result.spanStyles.size)
    }

    @Test
    fun `bright colors 90-97`() {
        val input = "\u001b[91mbright red\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("bright red", result.text)
        assertEquals(1, result.spanStyles.size)
    }

    @Test
    fun `256-color foreground basic`() {
        // 38;5;196 = bright red in 256-color
        val input = "\u001b[38;5;196mcolorful\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("colorful", result.text)
        assertEquals(1, result.spanStyles.size)
    }

    @Test
    fun `256-color standard palette 0-7`() {
        // 38;5;1 = standard red (same as code 31)
        val input = "\u001b[38;5;1mred\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("red", result.text)
        assertEquals(1, result.spanStyles.size)
    }

    @Test
    fun `256-color bright palette 8-15`() {
        // 38;5;9 = bright red (same as code 91)
        val input = "\u001b[38;5;9mbright\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("bright", result.text)
        assertEquals(1, result.spanStyles.size)
    }

    @Test
    fun `256-color RGB cube 16-231`() {
        // 38;5;21 = pure blue (0,0,255)
        val input = "\u001b[38;5;21mblue\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("blue", result.text)
        assertEquals(1, result.spanStyles.size)
    }

    @Test
    fun `256-color grayscale 232-255`() {
        // 38;5;240 = medium gray
        val input = "\u001b[38;5;240mgray\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("gray", result.text)
        assertEquals(1, result.spanStyles.size)
    }

    @Test
    fun `truecolor foreground 38-2-R-G-B`() {
        // 38;2;255;128;0 = orange
        val input = "\u001b[38;2;255;128;0morange\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("orange", result.text)
        assertEquals(1, result.spanStyles.size)
    }

    @Test
    fun `background color codes are ignored`() {
        // 48;5;21 = background blue, should be skipped
        val input = "\u001b[48;5;21mtext\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("text", result.text)
    }

    @Test
    fun `bold attribute produces FontWeight`() {
        val input = "\u001b[1mbold text\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("bold text", result.text)
        assertEquals(1, result.spanStyles.size)
    }

    @Test
    fun `reset clears all attributes`() {
        val input = "\u001b[1m\u001b[31mbold red\u001b[0m normal"
        val result = parseAnsiColors(input)
        assertEquals("bold red normal", result.text)
    }

    @Test
    fun `default foreground code 39 resets color`() {
        val input = "\u001b[31mred\u001b[39mdefault"
        val result = parseAnsiColors(input)
        assertEquals("reddefault", result.text)
        assertEquals(1, result.spanStyles.size) // only "red" has a span
    }

    @Test
    fun `non-color escape sequences are stripped`() {
        // Cursor movement: \u001b[A (up), \u001b[2J (clear screen)
        val input = "line1\u001b[Aline2\u001b[2Jline3"
        val result = parseAnsiColors(input)
        assertEquals("line1line2line3", result.text)
    }

    @Test
    fun `mixed 256-color and basic colors`() {
        val input = "\u001b[38;5;231mwhite\u001b[31mred\u001b[38;5;153mblue\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("whiteredblue", result.text)
        assertEquals(3, result.spanStyles.size)
    }

    @Test
    fun `Claude Code typical output with 256 colors`() {
        // Simulates actual Claude Code output format
        val input = "\u001b[38;5;231m❯\u001b[39m \u001b[1msubtask_234\u001b[0m done"
        val result = parseAnsiColors(input)
        assertEquals("❯ subtask_234 done", result.text)
    }

    @Test
    fun `dim attribute code 2`() {
        val input = "\u001b[2mdim text\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("dim text", result.text)
    }

    @Test
    fun `empty escape code resets`() {
        val input = "\u001b[31mred\u001b[mnormal"
        val result = parseAnsiColors(input)
        assertEquals("rednormal", result.text)
    }

    @Test
    fun `text with no escape sequences has no spans`() {
        val result = parseAnsiColors("just plain text with 日本語")
        assertEquals("just plain text with 日本語", result.text)
        assertEquals(0, result.spanStyles.size)
    }

    @Test
    fun `combined bold and color`() {
        val input = "\u001b[1;31mbold red\u001b[0m"
        val result = parseAnsiColors(input)
        assertEquals("bold red", result.text)
        assertEquals(1, result.spanStyles.size)
    }
}
