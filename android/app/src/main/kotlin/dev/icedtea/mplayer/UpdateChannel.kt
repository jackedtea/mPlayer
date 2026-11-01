package dev.icedtea.mplayer

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands a downloaded APK to the system installer.
 *
 * Dart finds the release, picks the APK for this device's ABI and downloads
 * it; this side only does the three things Dart cannot: name the ABIs the
 * device runs, say whether the user has let mPlayer install packages, and
 * start the installer with a `content://` URI it is allowed to read. As with
 * every channel here, **Kotlin decides nothing**.
 *
 * The installer is Android's own: it shows the permissions, asks the user to
 * confirm, and refuses an APK signed with a different key than the installed
 * app. Nothing here bypasses any of that.
 */
class UpdateChannel(
    private val activity: MainActivity,
) {

    companion object {
        const val CHANNEL = "dev.icedtea.mplayer/update"
        private const val TAG = "UpdateChannel"
        private const val APK_TYPE = "application/vnd.android.package-archive"
    }

    fun handle(method: String, args: Map<*, *>?, result: MethodChannel.Result) {
        when (method) {
            // Most preferred first, which is the order to pick an APK in.
            "supportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())

            "canInstall" -> result.success(canInstall())

            "openInstallSettings" -> {
                openInstallSettings()
                result.success(null)
            }

            "installApk" -> {
                val path = args?.get("path") as? String
                if (path == null) {
                    result.error("bad-args", "No APK path.", null)
                    return
                }
                result.success(install(File(path)))
            }

            else -> result.notImplemented()
        }
    }

    /** Below API 26 the permission was the global "Unknown sources" switch. */
    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()

    /** The per-app "Install unknown apps" page, opened on this app. */
    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${activity.packageName}"),
        )
        try {
            activity.startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "No unknown-sources settings page", e)
        }
    }

    /** True once the installer has been started; false if it could not be. */
    private fun install(apk: File): Boolean {
        if (!apk.isFile) return false

        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.updates",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, APK_TYPE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            activity.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "No package installer", e)
            false
        }
    }
}
