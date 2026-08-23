package dev.icedtea.mplayer

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * The Dart side of [PlaybackService].
 *
 * Dart pushes what is playing; the service turns that into a notification, a
 * media session and an audio focus request, and sends every button press back
 * the other way. Nothing about *what to do* lives on this side of the
 * boundary — the player in Dart decides, so the notification can never claim
 * a state the decoder is not in.
 */
class NowPlayingChannel(
    private val activity: Activity,
) {

    companion object {
        const val CHANNEL = "dev.icedtea.mplayer/now-playing"
        const val EVENTS = "dev.icedtea.mplayer/now-playing-events"

        /** Any code; nothing depends on the answer. See [askForNotifications]. */
        private const val NOTIFICATION_PERMISSION_REQUEST = 0x4E50
    }

    private var sink: EventChannel.EventSink? = null
    private var asked = false

    fun handle(call: String, arguments: Map<*, *>?, result: MethodChannel.Result) {
        when (call) {
            // One method for starting and updating: the service reads the same
            // extras either way, and a separate "start" would only be a second
            // path to keep in step.
            "update" -> {
                askForNotifications()
                start(arguments)
                result.success(null)
            }

            "stop" -> {
                stop()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    fun streamHandler(): EventChannel.StreamHandler =
        object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
                PlaybackService.listener = { control, position ->
                    // Broadcasts and session callbacks arrive on the main
                    // thread already, but focus changes need not, and an event
                    // sink may only be touched from the platform thread.
                    activity.runOnUiThread {
                        sink?.success(
                            mapOf(
                                "control" to control,
                                "positionMs" to position,
                            ),
                        )
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                sink = null
                PlaybackService.listener = null
            }
        }

    fun dispose() {
        PlaybackService.listener = null
        sink = null
        stop()
    }

    private fun start(arguments: Map<*, *>?) {
        val intent = Intent(activity, PlaybackService::class.java)
            .setAction(PlaybackService.ACTION_UPDATE)
            .putExtra(
                PlaybackService.EXTRA_TITLE,
                arguments?.get("title") as? String ?: "mPlayer",
            )
            .putExtra(
                PlaybackService.EXTRA_SUBTITLE,
                arguments?.get("subtitle") as? String ?: "",
            )
            .putExtra(
                PlaybackService.EXTRA_PLAYING,
                arguments?.get("playing") as? Boolean ?: false,
            )
            .putExtra(
                PlaybackService.EXTRA_POSITION_MS,
                (arguments?.get("positionMs") as? Number)?.toLong() ?: 0L,
            )
            .putExtra(
                PlaybackService.EXTRA_DURATION_MS,
                (arguments?.get("durationMs") as? Number)?.toLong() ?: 0L,
            )
            .putExtra(
                PlaybackService.EXTRA_SPEED,
                (arguments?.get("speed") as? Number)?.toFloat() ?: 1f,
            )
            .putExtra(
                PlaybackService.EXTRA_HAS_NEXT,
                arguments?.get("hasNext") as? Boolean ?: false,
            )
            .putExtra(
                PlaybackService.EXTRA_HAS_PREVIOUS,
                arguments?.get("hasPrevious") as? Boolean ?: false,
            )

        // startForegroundService, not startService: from Android 8 the plain
        // call throws once the app is no longer in the foreground, which is
        // exactly when this matters.
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                activity.startForegroundService(intent)
            } else {
                activity.startService(intent)
            }
        }.onFailure {
            Log.w("NowPlayingChannel", "Could not start the playback service", it)
        }
    }

    private fun stop() {
        runCatching {
            activity.startService(
                Intent(activity, PlaybackService::class.java)
                    .setAction(PlaybackService.ACTION_STOP),
            )
        }
    }

    /**
     * Asks once for permission to post the notification.
     *
     * Nothing waits on the answer: from Android 13 a denied permission hides
     * the notification but the foreground service still runs, so playback
     * carries on either way and the user is not blocked mid-film by a dialog
     * they have to clear before the video continues.
     */
    private fun askForNotifications() {
        if (asked) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        asked = true

        val granted = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return

        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }
}
