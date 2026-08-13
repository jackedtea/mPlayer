package dev.icedtea.mplayer

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Folder access through the Storage Access Framework.
 *
 * MediaStore covers the common case but cannot see everything: a folder
 * holding a `.nomedia` file is hidden from the index entirely, and containers
 * MediaScanner does not recognise never make it in. SAF is the way round that
 * — the user grants one folder, the grant survives reboots, and the app then
 * sees every file in it regardless of what the scanner thought.
 */
class SafChannel(
    private val activity: Activity,
) : PluginRegistry.ActivityResultListener {

    companion object {
        const val CHANNEL = "dev.icedtea.mplayer/saf"
        private const val PICK_FOLDER_REQUEST = 0x5361 // 'Sa'
    }

    private var pendingPick: MethodChannel.Result? = null

    fun handle(call: String, args: Map<*, *>?, result: MethodChannel.Result) {
        when (call) {
            "pickFolder" -> pickFolder(result)
            "persistedFolders" -> result.success(persistedFolders())
            "listTree" -> listTree(args, result)
            "releaseFolder" -> releaseFolder(args, result)
            else -> result.notImplemented()
        }
    }

    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("already_picking", "A picker is already open", null)
            return
        }
        pendingPick = result

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        activity.startActivityForResult(intent, PICK_FOLDER_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_FOLDER_REQUEST) return false

        val result = pendingPick
        pendingPick = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            // Cancelling is not an error; null tells Dart nothing was chosen.
            result?.success(null)
            return true
        }

        // Without this the grant dies with the process, and the folder would
        // silently stop working after a restart.
        activity.contentResolver.takePersistableUriPermission(
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )

        result?.success(describeTree(uri))
        return true
    }

    /** Folders granted earlier and still valid. */
    private fun persistedFolders(): List<Map<String, Any?>> =
        activity.contentResolver.persistedUriPermissions
            .filter { it.isReadPermission }
            .mapNotNull {
                runCatching { describeTree(it.uri) }.getOrNull()
            }

    private fun describeTree(treeUri: Uri): Map<String, Any?> {
        val docId = DocumentsContract.getTreeDocumentId(treeUri)
        return mapOf(
            "treeUri" to treeUri.toString(),
            "documentId" to docId,
            // The last path segment of a tree id is the closest thing SAF
            // offers to a folder name.
            "name" to docId.substringAfterLast('/').substringAfterLast(':'),
        )
    }

    private fun releaseFolder(args: Map<*, *>?, result: MethodChannel.Result) {
        val treeUri = (args?.get("treeUri") as? String)?.let(Uri::parse)
        if (treeUri == null) {
            result.error("bad_args", "treeUri is required", null)
            return
        }
        runCatching {
            activity.contentResolver.releasePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }
        result.success(true)
    }

    /** Children of one document in a granted tree. */
    private fun listTree(args: Map<*, *>?, result: MethodChannel.Result) {
        val treeUriString = args?.get("treeUri") as? String
        if (treeUriString == null) {
            result.error("bad_args", "treeUri is required", null)
            return
        }

        val treeUri = Uri.parse(treeUriString)
        val parentId = (args["documentId"] as? String)
            ?: DocumentsContract.getTreeDocumentId(treeUri)

        val childrenUri =
            DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentId)

        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )

        val out = mutableListOf<Map<String, Any?>>()
        try {
            activity.contentResolver
                .query(childrenUri, projection, null, null, null)
                ?.use { cursor ->
                    val idCol = cursor.getColumnIndexOrThrow(projection[0])
                    val nameCol = cursor.getColumnIndexOrThrow(projection[1])
                    val mimeCol = cursor.getColumnIndexOrThrow(projection[2])
                    val sizeCol = cursor.getColumnIndexOrThrow(projection[3])
                    val modifiedCol = cursor.getColumnIndexOrThrow(projection[4])

                    while (cursor.moveToNext()) {
                        val id = cursor.getString(idCol)
                        val mime = cursor.getString(mimeCol)
                        val isDir = mime == DocumentsContract.Document.MIME_TYPE_DIR

                        out.add(
                            mapOf(
                                "documentId" to id,
                                "name" to cursor.getString(nameCol),
                                "isDirectory" to isDir,
                                "mimeType" to mime,
                                "size" to
                                    if (cursor.isNull(sizeCol)) 0L
                                    else cursor.getLong(sizeCol),
                                "modifiedMs" to
                                    if (cursor.isNull(modifiedCol)) null
                                    else cursor.getLong(modifiedCol),
                                // The document URI is what actually opens; a
                                // document id alone is not addressable.
                                "uri" to DocumentsContract
                                    .buildDocumentUriUsingTree(treeUri, id)
                                    .toString(),
                            ),
                        )
                    }
                }
        } catch (e: SecurityException) {
            // A grant the user revoked in system settings.
            result.error("permission_revoked", "Access to this folder was revoked", null)
            return
        } catch (e: IllegalArgumentException) {
            result.error("not_found", "That folder no longer exists", null)
            return
        }

        result.success(out)
    }
}
