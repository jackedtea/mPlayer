package dev.icedtea.mplayer

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Files handed to mPlayer by another app — "Open with" from a file manager or
 * gallery, and the share sheet.
 *
 * Written by hand rather than taken from a plugin because every plugin in this
 * space resolves a `content://` URI by *copying the whole file into the app
 * cache* and returning the copy's path. For a photo that is invisible; for a
 * 20 GB remux it fills internal storage and stalls the launch for minutes.
 *
 * Nothing is copied here. The URI is passed through as-is, exactly like the
 * MediaStore and SAF browsers already do, and libmpv opens it through the
 * content resolver. The only thing read up front is the display name, so the
 * player has a title before the first frame.
 */
class IntentChannel(
    private val activity: Activity,
) {

    companion object {
        const val CHANNEL = "dev.icedtea.mplayer/intent"
        const val EVENTS = "dev.icedtea.mplayer/intent-events"
    }

    /**
     * A file that arrived before Dart was listening.
     *
     * Both the launch intent and — briefly, on a cold start — anything from
     * `onNewIntent` land here until [handle] drains it.
     */
    private var pending: Map<String, Any?>? = null

    private var sink: EventChannel.EventSink? = null

    fun handle(call: String, result: MethodChannel.Result) {
        when (call) {
            "initialMedia" -> {
                result.success(pending)
                pending = null
            }
            else -> result.notImplemented()
        }
    }

    fun streamHandler(): EventChannel.StreamHandler =
        object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
            }

            override fun onCancel(arguments: Any?) {
                sink = null
            }
        }

    /**
     * Offers an intent to Dart.
     *
     * Called for the intent that started the activity and again from
     * `onNewIntent` for every later one. Anything that is not a file hand-off
     * — the launcher icon, most of all — is ignored.
     */
    fun offer(intent: Intent?) {
        // Nothing an outside app sends is allowed to take down the launch. The
        // worst case is a file that does not open; a thrown exception here runs
        // inside onCreate and closes the app the instant it appears.
        val media = runCatching { describe(intent ?: return) }
            .onFailure { Log.w("IntentChannel", "Unusable intent", it) }
            .getOrNull() ?: return

        // The event sink is only alive once the Dart side has subscribed. On a
        // cold start it has not, and the file waits for the first
        // `initialMedia` call instead.
        val events = sink
        if (events != null) events.success(media) else pending = media
    }

    private fun describe(intent: Intent): Map<String, Any?>? {
        // Deliberately no "already handled" marker in the extras. Reading an
        // extra forces the whole Bundle to be unparcelled, and a foreign
        // intent routinely carries Parcelables whose classes this app does not
        // have — which throws BadParcelableException and kills the activity
        // before the first frame. ACTION_VIEW therefore touches intent.data
        // only, and the marker is not needed anyway: the launch intent is
        // offered once per engine, and onNewIntent fires once per intent.
        val uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.streamExtra()
            else -> null
        } ?: return null

        // Best effort: an "Open with" grant normally lasts only as long as the
        // task, which is enough to play the file. Asking for the persistable
        // form costs nothing and occasionally succeeds, which is what lets the
        // same file resume after a restart.
        if (uri.scheme == "content") {
            runCatching {
                activity.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
        }

        val (name, size) = openableColumns(uri)

        return mapOf(
            "uri" to uri.toString(),
            // Falling back to the last path segment covers file:// and the
            // providers that do not implement OpenableColumns.
            "title" to (name ?: uri.lastPathSegment ?: uri.toString()),
            "size" to size,
            "mimeType" to (intent.type
                ?: runCatching { activity.contentResolver.getType(uri) }.getOrNull()),
        )
    }

    /**
     * Display name and size, or nulls when the provider will not say.
     *
     * One cursor for both, because the query is the expensive part and a
     * provider that answers one column almost always answers the other.
     */
    private fun openableColumns(uri: Uri): Pair<String?, Long?> {
        if (uri.scheme != "content") return Pair(null, null)

        val projection = arrayOf(
            OpenableColumns.DISPLAY_NAME,
            OpenableColumns.SIZE,
        )

        return runCatching {
            activity.contentResolver
                .query(uri, projection, null, null, null)
                ?.use { cursor ->
                    if (!cursor.moveToFirst()) return@use Pair(null, null)

                    val nameCol = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeCol = cursor.getColumnIndex(OpenableColumns.SIZE)

                    Pair(
                        if (nameCol < 0 || cursor.isNull(nameCol)) null
                        else cursor.getString(nameCol),
                        if (sizeCol < 0 || cursor.isNull(sizeCol)) null
                        else cursor.getLong(sizeCol),
                    )
                } ?: Pair(null, null)
        }.getOrDefault(Pair(null, null))
    }

    /**
     * The shared file, or null when the extras cannot be read.
     *
     * Unparcelling a sender's Bundle can throw for reasons that have nothing to
     * do with this app; a share that cannot be decoded is worth dropping, not
     * crashing over.
     */
    private fun Intent.streamExtra(): Uri? = runCatching {
        when {
            Build.VERSION.SDK_INT >= 33 ->
                getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else ->
                @Suppress("DEPRECATION") getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }.getOrNull()
}
