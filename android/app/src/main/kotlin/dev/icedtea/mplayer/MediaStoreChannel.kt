package dev.icedtea.mplayer

import android.app.Activity
import android.content.ContentUris
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Reads the system media index.
 *
 * Scoped storage means an app cannot simply list `/storage/emulated/0`, so the
 * "This device" section is built from MediaStore instead. This deliberately
 * queries the *files* collection filtered by extension rather than the video
 * collection: MediaScanner classifies `.rmvb`, `.vob` and `.divx` as
 * `application/octet-stream`, so they are missing from `Video.Media` entirely
 * — measured, not assumed — and those are exactly the formats this player
 * bundles a full libmpv to handle.
 */
class MediaStoreChannel(
    private val activity: Activity,
) : PluginRegistry.RequestPermissionsResultListener {

    companion object {
        const val CHANNEL = "dev.icedtea.mplayer/mediastore"
        private const val PERMISSION_REQUEST = 0x6D64 // 'md'

        /** Containers worth listing. Kept in step with videoFileExtensions in Dart. */
        private val VIDEO_EXTENSIONS = listOf(
            "mp4", "mkv", "mov", "avi", "webm", "m4v", "ts", "m2ts", "mts",
            "mpg", "mpeg", "wmv", "flv", "3gp", "ogv", "rmvb", "vob", "divx",
        )
    }

    private var pendingPermission: MethodChannel.Result? = null

    fun handle(method: String, result: MethodChannel.Result) {
        when (method) {
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> requestPermission(result)
            "videoFolders" -> guarded(result) { result.success(queryFolders()) }
            else -> result.notImplemented()
        }
    }

    fun handleVideosIn(bucketId: String?, result: MethodChannel.Result) {
        guarded(result) { result.success(queryVideos(bucketId)) }
    }

    /** Every query needs the permission; refusing loudly beats an empty list. */
    private inline fun guarded(result: MethodChannel.Result, body: () -> Unit) {
        if (!hasPermission()) {
            result.error("permission_denied", "Media permission not granted", null)
            return
        }
        body()
    }

    private fun permissionName(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            "android.permission.READ_MEDIA_VIDEO"
        } else {
            "android.permission.READ_EXTERNAL_STORAGE"
        }

    private fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(activity, permissionName()) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        // Only one request may be in flight; a second would strand the first.
        if (pendingPermission != null) {
            result.error("already_requesting", "A request is already pending", null)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(permissionName()),
            PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(granted)
        pendingPermission = null
        return true
    }

    /**
     * `WHERE _display_name LIKE '%.mkv' OR ...`, because MIME cannot be
     * trusted for the awkward containers.
     */
    private fun extensionSelection(): Pair<String, Array<String>> {
        val clause = VIDEO_EXTENSIONS.joinToString(" OR ") {
            "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?"
        }
        val args = VIDEO_EXTENSIONS.map { "%.$it" }.toTypedArray()
        return clause to args
    }

    private fun collection() =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Files.getContentUri("external")
        }

    /** Folders holding at least one video, with a count each. */
    private fun queryFolders(): List<Map<String, Any?>> {
        val (clause, args) = extensionSelection()
        val projection = arrayOf(
            MediaStore.Files.FileColumns.BUCKET_ID,
            MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME,
            MediaStore.Files.FileColumns.DATA,
        )

        // Counted in code rather than with GROUP BY: the ContentResolver API
        // has no portable grouping, and the row count here is small.
        val counts = LinkedHashMap<String, MutableMap<String, Any?>>()

        activity.contentResolver.query(
            collection(), projection, clause, args,
            "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC",
        )?.use { cursor ->
            val bucketIdCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.BUCKET_ID)
            val bucketNameCol =
                cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.BUCKET_DISPLAY_NAME)
            val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)

            while (cursor.moveToNext()) {
                val id = cursor.getString(bucketIdCol) ?: continue
                val entry = counts.getOrPut(id) {
                    mutableMapOf(
                        "id" to id,
                        "name" to (cursor.getString(bucketNameCol) ?: "Unknown"),
                        "path" to (cursor.getString(dataCol)?.substringBeforeLast('/') ?: ""),
                        "count" to 0,
                    )
                }
                entry["count"] = (entry["count"] as Int) + 1
            }
        }

        return counts.values.toList()
    }

    /** Videos in one folder, or everywhere when [bucketId] is null. */
    private fun queryVideos(bucketId: String?): List<Map<String, Any?>> {
        val (extClause, extArgs) = extensionSelection()

        val clause: String
        val args: Array<String>
        if (bucketId == null) {
            clause = extClause
            args = extArgs
        } else {
            clause = "(${extClause}) AND ${MediaStore.Files.FileColumns.BUCKET_ID} = ?"
            args = extArgs + bucketId
        }

        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.DATA,
        )

        val out = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(
            collection(), projection, clause, args,
            "${MediaStore.Files.FileColumns.DISPLAY_NAME} COLLATE NOCASE ASC",
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val modifiedCol =
                cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                // A content:// URI, not the raw path: scoped storage may
                // refuse the file path even when MediaStore lists it.
                val uri = ContentUris.withAppendedId(collection(), id)

                out.add(
                    mapOf(
                        "id" to id.toString(),
                        "name" to cursor.getString(nameCol),
                        "uri" to uri.toString(),
                        "path" to cursor.getString(dataCol),
                        "size" to cursor.getLong(sizeCol),
                        // MediaStore stores seconds; Dart works in millis.
                        "modifiedMs" to cursor.getLong(modifiedCol) * 1000,
                    ),
                )
            }
        }
        return out
    }
}
