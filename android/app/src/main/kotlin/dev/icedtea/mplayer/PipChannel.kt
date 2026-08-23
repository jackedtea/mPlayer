package dev.icedtea.mplayer

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Log
import android.util.Rational
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Picture in picture, and the transport buttons Android draws inside the PiP
 * window.
 *
 * Only Android has this: the desktop equivalent would be an always-on-top
 * window, which is a different feature with a different implementation, so
 * [isSupported] answers false everywhere else and the button never appears.
 *
 * The window's own controls arrive as broadcasts rather than method calls —
 * the system, not Flutter, owns those buttons — so they are forwarded to Dart
 * on the event channel and applied by the player there. Keeping the decision
 * in Dart is what stops the two sides disagreeing about whether playback is
 * running.
 */
class PipChannel(
    private val activity: MainActivity,
) {

    companion object {
        const val CHANNEL = "dev.icedtea.mplayer/pip"
        const val EVENTS = "dev.icedtea.mplayer/pip-events"

        /** API 26 introduced PiP; the whole feature is inert below it. */
        private const val MIN_SDK = Build.VERSION_CODES.O

        /** API 31 can enter PiP on its own when the user leaves. */
        private const val AUTO_ENTER_SDK = Build.VERSION_CODES.S

        private const val ACTION_CONTROL = "dev.icedtea.mplayer.PIP_CONTROL"
        private const val EXTRA_CONTROL = "control"

        private const val CONTROL_BACK = "back"
        private const val CONTROL_TOGGLE = "toggle"
        private const val CONTROL_FORWARD = "forward"

        /**
         * Android rejects an aspect ratio outside roughly 1:2.39 … 2.39:1 by
         * throwing, which would take the app down for the sake of a window.
         */
        private const val MIN_ASPECT = 1.0 / 2.39
        private const val MAX_ASPECT = 2.39
    }

    private var sink: EventChannel.EventSink? = null

    /** Mirrors what was last handed to the system, so a params refresh does
     *  not need the caller to repeat itself. */
    private var aspect: Rational = Rational(16, 9)
    private var playing: Boolean = false
    private var autoEnter: Boolean = false

    private var receiverRegistered = false

    private val controls = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val control = intent?.getStringExtra(EXTRA_CONTROL) ?: return
            sink?.success(mapOf("type" to "control", "control" to control))
        }
    }

    fun handle(call: String, arguments: Map<*, *>?, result: MethodChannel.Result) {
        when (call) {
            "isSupported" -> result.success(isSupported())

            "enter" -> {
                remember(arguments)
                result.success(enter())
            }

            // Called whenever the video, the play state or the page changes,
            // so the window's buttons and shape stay honest — and so API 31+
            // knows whether leaving the app should open PiP at all.
            "update" -> {
                remember(arguments)
                applyParams()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    fun streamHandler(): EventChannel.StreamHandler =
        object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
                registerReceiver()
            }

            override fun onCancel(arguments: Any?) {
                sink = null
            }
        }

    /** Reported by the activity so Dart can drop the chrome: a PiP window is
     *  a few hundred pixels wide and has no room for controls. */
    fun onModeChanged(inPip: Boolean) {
        if (!inPip) {
            // Leaving PiP also cancels the auto-enter request; the player
            // re-arms it if it is still on screen and still playing.
            autoEnter = false
        }
        sink?.success(mapOf("type" to "mode", "inPip" to inPip))
    }

    /**
     * The user pressed Home or Recents.
     *
     * API 31+ enters on its own from the params, so this is only the manual
     * path for 26–30 — and only when the player asked for it.
     */
    fun onUserLeaveHint() {
        if (Build.VERSION.SDK_INT >= AUTO_ENTER_SDK) return
        if (!autoEnter) return
        enter()
    }

    fun dispose() {
        if (receiverRegistered) {
            runCatching { activity.unregisterReceiver(controls) }
            receiverRegistered = false
        }
        sink = null
    }

    private fun isSupported(): Boolean {
        if (Build.VERSION.SDK_INT < MIN_SDK) return false
        return activity.packageManager
            .hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun remember(arguments: Map<*, *>?) {
        playing = arguments?.get("playing") as? Boolean ?: playing
        autoEnter = arguments?.get("autoEnter") as? Boolean ?: autoEnter

        val width = (arguments?.get("width") as? Number)?.toDouble()
        val height = (arguments?.get("height") as? Number)?.toDouble()
        if (width != null && height != null && width > 0 && height > 0) {
            aspect = rationalFor(width / height)
        }
    }

    /**
     * Clamps to what the platform accepts and hands back a small rational.
     *
     * The denominator is capped because the system compares aspect ratios
     * with integer arithmetic; a 1920:817 style pair is accepted but a
     * pathological one from a broken header is not worth risking.
     */
    private fun rationalFor(ratio: Double): Rational {
        val clamped = ratio.coerceIn(MIN_ASPECT, MAX_ASPECT)
        return Rational((clamped * 1000).toInt(), 1000)
    }

    private fun enter(): Boolean {
        if (!isSupported()) return false
        if (activity.isFinishing) return false

        return runCatching {
            activity.enterPictureInPictureMode(params())
        }.onFailure {
            // A device can refuse — a manufacturer skin with PiP disabled, or
            // a permission the user revoked in app settings. Reporting false
            // lets the player leave the video where it is instead of dying.
            Log.w("PipChannel", "Could not enter picture in picture", it)
        }.getOrDefault(false)
    }

    private fun applyParams() {
        if (!isSupported()) return
        runCatching { activity.setPictureInPictureParams(params()) }
            .onFailure { Log.w("PipChannel", "Could not update PiP params", it) }
    }

    private fun params(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(aspect)
            .setActions(actions())

        if (Build.VERSION.SDK_INT >= AUTO_ENTER_SDK) {
            builder.setAutoEnterEnabled(autoEnter)
            // Without this the window flashes the app's background while the
            // video surface is re-laid out on the way in and out.
            builder.setSeamlessResizeEnabled(true)
        }

        return builder.build()
    }

    /**
     * Skip back, play/pause, skip forward.
     *
     * Three is what every device allows; asking for more than
     * `maxNumPictureInPictureActions` silently drops the extras.
     */
    private fun actions(): List<RemoteAction> {
        val toggleIcon = if (playing) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val toggleLabel = if (playing) "Pause" else "Play"

        return listOf(
            action(CONTROL_BACK, "Rewind", android.R.drawable.ic_media_rew),
            action(CONTROL_TOGGLE, toggleLabel, toggleIcon),
            action(CONTROL_FORWARD, "Forward", android.R.drawable.ic_media_ff),
        )
    }

    private fun action(control: String, label: String, icon: Int): RemoteAction {
        val intent = Intent(ACTION_CONTROL)
            .setPackage(activity.packageName)
            .putExtra(EXTRA_CONTROL, control)

        val pending = PendingIntent.getBroadcast(
            activity,
            // A distinct request code per control: they differ only in an
            // extra, and PendingIntent equality ignores extras — one code for
            // all three would hand every button the same action.
            control.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return RemoteAction(
            Icon.createWithResource(activity, icon),
            label,
            label,
            pending,
        )
    }

    private fun registerReceiver() {
        if (receiverRegistered) return

        val filter = IntentFilter(ACTION_CONTROL)
        // The buttons are ours and nothing outside the app may press them.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(controls, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            activity.registerReceiver(controls, filter)
        }
        receiverRegistered = true
    }
}
