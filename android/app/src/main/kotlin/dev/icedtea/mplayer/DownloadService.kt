package dev.icedtea.mplayer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Keeps the process alive while downloads run, and says how far they are.
 *
 * The downloading itself happens in Dart, inside the Flutter engine this
 * process already hosts. Android stops a process with nothing visible, so
 * without a foreground service a film half fetched when the user switched
 * apps would stop there. This service is that foreground service and the
 * notification it must carry — nothing more: which file, how far and when
 * to stop are all Dart's, pushed through [DownloadChannel].
 *
 * `dataSync` is the type Android gives user-started transfers. From Android
 * 15 it is capped at six hours a day; a queue that outlasts that is stopped
 * by the system and resumes from the partial file on the next launch.
 */
class DownloadService : Service() {

    companion object {
        const val ACTION_UPDATE = "dev.icedtea.mplayer.download.UPDATE"
        const val ACTION_STOP = "dev.icedtea.mplayer.download.STOP"

        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"

        /** 0–100, or -1 while the size is unknown. */
        const val EXTRA_PERCENT = "percent"

        private const val CHANNEL_ID = "downloads"
        private const val NOTIFICATION_ID = 0x6D44 // 'mD'
    }

    private var started = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stop()
            return START_NOT_STICKY
        }

        val notification = notification(
            title = intent?.getStringExtra(EXTRA_TITLE) ?: "mPlayer",
            text = intent?.getStringExtra(EXTRA_TEXT) ?: "",
            percent = intent?.getIntExtra(EXTRA_PERCENT, -1) ?: -1,
        )

        if (!started) {
            startAsForeground(notification)
            started = true
        } else {
            getSystemService(NotificationManager::class.java)
                ?.notify(NOTIFICATION_ID, notification)
        }

        // Not sticky: restarted by the system with no engine behind it, the
        // service would show progress for downloads nothing is running.
        return START_NOT_STICKY
    }

    /** Swiped out of recents: the engine doing the work is going too. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        stop()
        super.onTaskRemoved(rootIntent)
    }

    private fun startAsForeground(notification: Notification) {
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        }.onFailure {
            // Refused when started from the background on Android 12+, or
            // once the daily dataSync allowance is spent. The download keeps
            // going while the app is open either way.
            Log.w("DownloadService", "Could not go foreground", it)
        }
    }

    private fun stop() {
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
            "Downloads",
            // Low: progress is something to glance at, not to be buzzed by.
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Films and episodes being saved for offline viewing"
            setShowBadge(false)
        }

        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    private fun notification(title: String, text: String, percent: Int): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }

        return builder
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(openApp())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, percent.coerceIn(0, 100), percent < 0)
            .build()
    }

    private fun openApp(): PendingIntent? {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: return null
        return PendingIntent.getActivity(
            this,
            1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
