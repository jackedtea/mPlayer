package dev.icedtea.mplayer

import android.content.Context
import android.database.ContentObserver
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/**
 * The device's media volume — the one its own buttons move — for the
 * player's "Sync volume with device" setting.
 *
 * As with every channel here, Kotlin decides nothing: it reads the level,
 * writes the level it is given, and reports when something else (the
 * hardware buttons, the system panel) moved it. Levels cross as a fraction
 * of the stream's maximum, since the number of steps differs per device.
 */
class VolumeChannel(context: Context) {

    companion object {
        const val CHANNEL = "dev.icedtea.mplayer/volume"
        const val EVENTS = "dev.icedtea.mplayer/volume-events"
    }

    private val resolver = context.applicationContext.contentResolver
    private val audio =
        context.applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private var sink: EventChannel.EventSink? = null
    private var lastSent: Double? = null

    /** Volume changes are written to system settings, so watching those is
     *  how a press of the hardware buttons is heard without a receiver. */
    private val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
        override fun onChange(selfChange: Boolean) {
            val now = fraction()
            if (now == lastSent) return
            lastSent = now
            sink?.success(now)
        }
    }

    private fun fraction(): Double {
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0.0
        return audio.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
    }

    fun handle(call: String, arguments: Map<*, *>?, result: MethodChannel.Result) {
        when (call) {
            "get" -> result.success(fraction())
            "set" -> {
                val wanted = (arguments?.get("fraction") as? Number)?.toDouble()
                if (wanted == null) {
                    result.error("bad-args", "fraction is required", null)
                    return
                }
                val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val index = (wanted.coerceIn(0.0, 1.0) * max).roundToInt()
                try {
                    // No flags: the player draws its own indicator, and the
                    // system's panel on top of it would be two of them.
                    audio.setStreamVolume(AudioManager.STREAM_MUSIC, index, 0)
                    lastSent = fraction()
                    result.success(lastSent)
                } catch (e: SecurityException) {
                    // Do Not Disturb refuses changes that would unmute.
                    result.error("refused", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    fun streamHandler() = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            sink = events
            lastSent = fraction()
            resolver.registerContentObserver(Settings.System.CONTENT_URI, true, observer)
        }

        override fun onCancel(arguments: Any?) {
            resolver.unregisterContentObserver(observer)
            sink = null
        }
    }

    fun dispose() {
        resolver.unregisterContentObserver(observer)
        sink = null
    }
}
