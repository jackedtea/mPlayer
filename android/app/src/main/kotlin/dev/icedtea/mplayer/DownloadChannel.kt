package dev.icedtea.mplayer

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

/**
 * The Dart side of [DownloadService]: "show this progress" and "stop".
 *
 * Dart sends an update whenever the running download's percent or the
 * queue changes, and a stop when nothing is left to fetch. The service
 * decides nothing.
 */
class DownloadChannel(
    private val activity: Activity,
) {

    companion object {
        const val CHANNEL = "dev.icedtea.mplayer/downloads"

        private const val NOTIFICATION_PERMISSION_REQUEST = 0x4E44
    }

    private var asked = false

    fun handle(call: String, arguments: Map<*, *>?, result: MethodChannel.Result) {
        when (call) {
            "update" -> {
                askForNotifications()
                update(arguments)
                result.success(null)
            }

            "stop" -> {
                stop()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    fun dispose() = stop()

    private fun update(arguments: Map<*, *>?) {
        val intent = Intent(activity, DownloadService::class.java)
            .setAction(DownloadService.ACTION_UPDATE)
            .putExtra(DownloadService.EXTRA_TITLE, arguments?.get("title") as? String ?: "mPlayer")
            .putExtra(DownloadService.EXTRA_TEXT, arguments?.get("text") as? String ?: "")
            .putExtra(
                DownloadService.EXTRA_PERCENT,
                (arguments?.get("percent") as? Number)?.toInt() ?: -1,
            )

        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                activity.startForegroundService(intent)
            } else {
                activity.startService(intent)
            }
        }.onFailure {
            Log.w("DownloadChannel", "Could not start the download service", it)
        }
    }

    private fun stop() {
        runCatching {
            activity.startService(
                Intent(activity, DownloadService::class.java)
                    .setAction(DownloadService.ACTION_STOP),
            )
        }
    }

    /**
     * Once per launch, and nothing waits on the answer: a denial hides the
     * notification and the service still runs.
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
