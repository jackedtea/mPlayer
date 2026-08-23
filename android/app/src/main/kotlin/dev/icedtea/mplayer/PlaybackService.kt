package dev.icedtea.mplayer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Keeps playback alive with the app in the background, and puts it in the
 * notification shade and on the lock screen.
 *
 * Android stops a process that has nothing visible; a foreground service is
 * the only thing that keeps the decoder running once the user leaves. The
 * service owns three things that go with that: the notification, a
 * [MediaSession] so headset buttons and the lock screen work, and audio
 * focus, so mPlayer yields to a call and does not talk over another player.
 *
 * It decides nothing. Every button and every focus change is forwarded to
 * Dart, which owns the actual player — two sides both acting on the same
 * event is how a notification ends up saying "playing" over silence.
 */
class PlaybackService : Service() {

    companion object {
        const val ACTION_UPDATE = "dev.icedtea.mplayer.NOW_PLAYING_UPDATE"
        const val ACTION_STOP = "dev.icedtea.mplayer.NOW_PLAYING_STOP"
        private const val ACTION_CONTROL = "dev.icedtea.mplayer.NOW_PLAYING_CONTROL"
        private const val EXTRA_CONTROL = "control"

        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_PLAYING = "playing"
        const val EXTRA_POSITION_MS = "positionMs"
        const val EXTRA_DURATION_MS = "durationMs"
        const val EXTRA_SPEED = "speed"
        const val EXTRA_HAS_NEXT = "hasNext"
        const val EXTRA_HAS_PREVIOUS = "hasPrevious"

        const val CONTROL_PLAY = "play"
        const val CONTROL_PAUSE = "pause"
        const val CONTROL_NEXT = "next"
        const val CONTROL_PREVIOUS = "previous"
        const val CONTROL_STOP = "stop"
        const val CONTROL_SEEK = "seek"

        private const val CHANNEL_ID = "playback"
        private const val NOTIFICATION_ID = 0x6D50 // 'mP'

        /**
         * Where a button press goes. Set by [NowPlayingChannel] for as long as
         * the Flutter engine is alive and cleared with it — a press arriving
         * after that has nobody to act on it and is dropped.
         */
        @Volatile
        @JvmStatic
        var listener: ((control: String, position: Long?) -> Unit)? = null
    }

    private var session: MediaSession? = null
    private var focusRequest: AudioFocusRequest? = null
    private var receiverRegistered = false
    private var started = false

    private var title: String = "mPlayer"
    private var subtitle: String? = null
    private var playing: Boolean = false
    private var positionMs: Long = 0
    private var durationMs: Long = 0
    private var speed: Float = 1f
    private var hasNext: Boolean = false
    private var hasPrevious: Boolean = false

    /**
     * One receiver for both the notification buttons and the headphone jack.
     *
     * Pulling headphones out is not a button, but the response is the same as
     * pressing pause, and a second receiver would only be a second thing to
     * unregister.
     */
    private val controls = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                AudioManager.ACTION_AUDIO_BECOMING_NOISY ->
                    listener?.invoke(CONTROL_PAUSE, null)
                ACTION_CONTROL -> {
                    val control = intent.getStringExtra(EXTRA_CONTROL) ?: return
                    listener?.invoke(control, null)
                }
            }
        }
    }

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            // Ducking is not offered: lowering a film's volume for a
            // notification chime leaves the user having missed the dialogue
            // either way, so mPlayer pauses and lets them resume.
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK,
            -> listener?.invoke(CONTROL_PAUSE, null)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        createSession()
        registerControls()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stop()
            return START_NOT_STICKY
        }

        read(intent)
        publish()

        // Not sticky: a service Android restarts by itself would put up a
        // notification for a player that is no longer running.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        abandonFocus()
        if (receiverRegistered) {
            runCatching { unregisterReceiver(controls) }
            receiverRegistered = false
        }
        session?.release()
        session = null
        super.onDestroy()
    }

    /** The app was swiped out of recents. Nothing is playing any more. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        listener?.invoke(CONTROL_STOP, null)
        stop()
        super.onTaskRemoved(rootIntent)
    }

    private fun read(intent: Intent?) {
        intent ?: return
        title = intent.getStringExtra(EXTRA_TITLE) ?: title
        subtitle = intent.getStringExtra(EXTRA_SUBTITLE) ?: subtitle
        playing = intent.getBooleanExtra(EXTRA_PLAYING, playing)
        positionMs = intent.getLongExtra(EXTRA_POSITION_MS, positionMs)
        durationMs = intent.getLongExtra(EXTRA_DURATION_MS, durationMs)
        speed = intent.getFloatExtra(EXTRA_SPEED, speed)
        hasNext = intent.getBooleanExtra(EXTRA_HAS_NEXT, hasNext)
        hasPrevious = intent.getBooleanExtra(EXTRA_HAS_PREVIOUS, hasPrevious)
    }

    private fun publish() {
        if (playing) requestFocus()

        session?.apply {
            isActive = true
            setMetadata(metadata())
            setPlaybackState(playbackState())
        }

        val notification = notification()

        if (!started) {
            startAsForeground(notification)
            started = true
        } else {
            val manager = getSystemService(NotificationManager::class.java)
            manager?.notify(NOTIFICATION_ID, notification)
        }
    }

    private fun startAsForeground(notification: Notification) {
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        }.onFailure {
            // Android 12+ refuses a foreground service started from the
            // background. Playback itself is unaffected while the app is
            // still up, so this is logged rather than crashed on.
            Log.w("PlaybackService", "Could not go foreground", it)
        }
    }

    private fun stop() {
        abandonFocus()
        session?.isActive = false
        started = false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION") stopForeground(true)
        }
        stopSelf()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Playback",
            // Low: this notification is a control surface, not news. IMPORTANCE_
            // DEFAULT would buzz the device every time a file opens.
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Controls for the video playing now"
            setShowBadge(false)
        }

        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    private fun createSession() {
        val media = MediaSession(this, "mPlayer")
        media.setCallback(object : MediaSession.Callback() {
            override fun onPlay() {
                listener?.invoke(CONTROL_PLAY, null)
            }

            override fun onPause() {
                listener?.invoke(CONTROL_PAUSE, null)
            }

            override fun onSkipToNext() {
                listener?.invoke(CONTROL_NEXT, null)
            }

            override fun onSkipToPrevious() {
                listener?.invoke(CONTROL_PREVIOUS, null)
            }

            override fun onStop() {
                listener?.invoke(CONTROL_STOP, null)
            }

            /** Dragging the lock screen scrubber. */
            override fun onSeekTo(pos: Long) {
                listener?.invoke(CONTROL_SEEK, pos)
            }
        })
        session = media
    }

    private fun metadata(): MediaMetadata =
        MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, subtitle ?: "")
            // A duration of 0 tells the lock screen there is nothing to scrub,
            // which is the honest answer before the file is demuxed.
            .putLong(MediaMetadata.METADATA_KEY_DURATION, durationMs)
            .build()

    private fun playbackState(): PlaybackState {
        var actions = PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_SEEK_TO or
            PlaybackState.ACTION_STOP
        if (hasNext) actions = actions or PlaybackState.ACTION_SKIP_TO_NEXT
        if (hasPrevious) actions = actions or PlaybackState.ACTION_SKIP_TO_PREVIOUS

        return PlaybackState.Builder()
            .setActions(actions)
            .setState(
                if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                positionMs,
                // The system extrapolates the position from here using the
                // speed, so a paused player must report 0 or the lock screen
                // scrubber keeps crawling forward.
                if (playing) speed else 0f,
            )
            .build()
    }

    private fun notification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }

        val style = Notification.MediaStyle()
            .setShowActionsInCompactView(0, 1, 2)
        session?.sessionToken?.let { style.setMediaSession(it) }

        builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(subtitle ?: "")
            .setContentIntent(openApp())
            .setDeleteIntent(pendingControl(CONTROL_STOP))
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(playing)
            .setStyle(style)
            .addAction(
                action(CONTROL_PREVIOUS, "Previous", android.R.drawable.ic_media_previous),
            )
            .addAction(
                if (playing) {
                    action(CONTROL_PAUSE, "Pause", android.R.drawable.ic_media_pause)
                } else {
                    action(CONTROL_PLAY, "Play", android.R.drawable.ic_media_play)
                },
            )
            .addAction(
                action(CONTROL_NEXT, "Next", android.R.drawable.ic_media_next),
            )

        return builder.build()
    }

    private fun openApp(): PendingIntent? {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: return null
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun action(control: String, label: String, icon: Int): Notification.Action =
        Notification.Action.Builder(icon, label, pendingControl(control)).build()

    private fun pendingControl(control: String): PendingIntent {
        val intent = Intent(ACTION_CONTROL)
            .setPackage(packageName)
            .putExtra(EXTRA_CONTROL, control)

        return PendingIntent.getBroadcast(
            this,
            // Distinct per control: PendingIntent equality ignores extras, so
            // one request code would give every button the same action.
            control.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun registerControls() {
        if (receiverRegistered) return

        val filter = IntentFilter(ACTION_CONTROL).apply {
            // Headphones pulled out, or bluetooth disconnected. Without this
            // the film carries on out loud from the phone's speaker.
            addAction(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(controls, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(controls, filter)
        }
        receiverRegistered = true
    }

    private fun requestFocus() {
        if (focusRequest != null) return
        val manager = getSystemService(AudioManager::class.java) ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                        .build(),
                )
                .setOnAudioFocusChangeListener(focusListener)
                .build()
            focusRequest = request
            manager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(
                focusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            )
        }
    }

    private fun abandonFocus() {
        val manager = getSystemService(AudioManager::class.java) ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { manager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION") manager.abandonAudioFocus(focusListener)
        }
        focusRequest = null
    }
}
