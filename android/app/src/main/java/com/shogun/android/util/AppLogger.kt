package com.shogun.android.util

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CopyOnWriteArrayList

object AppLogger {
    private val entries = CopyOnWriteArrayList<String>()
    private const val MAX_ENTRIES = 200
    private val fmt = SimpleDateFormat("HH:mm:ss.SSS", Locale.getDefault())

    fun log(tag: String, message: String) {
        val ts = fmt.format(Date())
        val entry = "$ts [$tag] $message"
        entries.add(entry)
        while (entries.size > MAX_ENTRIES) {
            entries.removeAt(0)
        }
    }

    fun getEntries(): List<String> = entries.toList()

    fun clear() = entries.clear()
}
