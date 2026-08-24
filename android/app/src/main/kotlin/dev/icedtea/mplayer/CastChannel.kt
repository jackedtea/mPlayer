package dev.icedtea.mplayer

import android.app.Activity
import android.util.Log
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaSeekOptions
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Chromecast, behind the same contract as the DLNA renderer in Dart.
 *
 * Only the *mechanism* differs from DLNA: discovery is `MediaRouter` rather
 * than SSDP, and transport is `RemoteMediaClient` rather than SOAP. Which
 * device a user picked, what to load and when to give up are all decided in
 * Dart, so the two protocols cannot grow separate behaviours.
 *
 * Everything is guarded, because this is the one channel whose dependency can
 * simply be absent: a device without Google Play Services throws from the
 * first `CastContext` call, and the answer to that is a picker that lists no
 * Chromecasts, not a crash.
 */
class CastChannel(
    private val activity: Activity,
) {

    companion object {
        const val CHANNEL = "dev.icedtea.mplayer/chromecast"
        const val EVENTS = "dev.icedtea.mplayer/chromecast-events"
        private const val TAG = "CastChannel"
    }

    private var sink: EventChannel.EventSink? = null
    private var router: MediaRouter? = null
    private var scanning = false

    /** Null when Play Services is missing, or too old to serve this SDK. */
    private val castContext: CastContext?
        get() = runCatching { CastContext.getSharedInstance(activity) }
            .onFailure { Log.i(TAG, "Cast is unavailable on this device: $it") }
            .getOrNull()

    private val session: CastSession?
        get() = castContext?.sessionManager?.currentCastSession

    private val selector: MediaRouteSelector
        get() = MediaRouteSelector.Builder()
            .addControlCategory(
                CastMediaControlIntent.categoryForCast(
                    CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID,
                ),
            )
            .build()

    private val routerCallback = object : MediaRouter.Callback() {
        override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) =
            publishDevices()

        override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) =
            publishDevices()

        override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) =
            publishDevices()
    }

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarted(session: CastSession, sessionId: String) =
            publishSession(true)

        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) =
            publishSession(true)

        override fun onSessionEnded(session: CastSession, error: Int) =
            publishSession(false)

        override fun onSessionSuspended(session: CastSession, reason: Int) =
            publishSession(false)

        override fun onSessionStartFailed(session: CastSession, error: Int) =
            publishSession(false)

        override fun onSessionResumeFailed(session: CastSession, error: Int) =
            publishSession(false)

        override fun onSessionStarting(session: CastSession) = Unit
        override fun onSessionEnding(session: CastSession) = Unit
        override fun onSessionResuming(session: CastSession, sessionId: String) = Unit
    }

    fun handle(call: String, arguments: Map<*, *>?, result: MethodChannel.Result) {
        try {
            when (call) {
                "isAvailable" -> result.success(castContext != null)
                "startDiscovery" -> {
                    startDiscovery()
                    result.success(null)
                }
                "stopDiscovery" -> {
                    stopDiscovery()
                    result.success(null)
                }
                "connect" -> connect(arguments?.get("id") as? String, result)
                "load" -> load(arguments, result)
                "play" -> {
                    remote(result) { it.play() }
                }
                "pause" -> {
                    remote(result) { it.pause() }
                }
                "stop" -> {
                    remote(result) { it.stop() }
                }
                "seek" -> {
                    val ms = (arguments?.get("positionMs") as? Number)?.toLong() ?: 0L
                    remote(result) {
                        it.seek(MediaSeekOptions.Builder().setPosition(ms).build())
                    }
                }
                "status" -> result.success(status())
                "disconnect" -> {
                    disconnect()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // The SDK throws from more places than it documents, and none of
            // them are worth taking the app down for.
            Log.w(TAG, "Cast call '$call' failed", e)
            result.error("cast_failed", e.message ?: "Cast failed", null)
        }
    }

    fun streamHandler(): EventChannel.StreamHandler =
        object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
                runCatching {
                    castContext?.sessionManager?.addSessionManagerListener(
                        sessionListener,
                        CastSession::class.java,
                    )
                }
            }

            override fun onCancel(arguments: Any?) {
                sink = null
                runCatching {
                    castContext?.sessionManager?.removeSessionManagerListener(
                        sessionListener,
                        CastSession::class.java,
                    )
                }
            }
        }

    fun dispose() {
        stopDiscovery()
        runCatching {
            castContext?.sessionManager?.removeSessionManagerListener(
                sessionListener,
                CastSession::class.java,
            )
        }
        sink = null
    }

    /**
     * Starts an active scan.
     *
     * Active rather than passive because the picker is open and waiting:
     * passive discovery reports what the platform already knows, which on a
     * cold start is nothing. It costs battery, which is why [stopDiscovery]
     * is called as soon as the sheet closes.
     */
    private fun startDiscovery() {
        if (scanning) return
        if (castContext == null) return

        val instance = router ?: MediaRouter.getInstance(activity).also { router = it }
        instance.addCallback(
            selector,
            routerCallback,
            MediaRouter.CALLBACK_FLAG_PERFORM_ACTIVE_SCAN,
        )
        scanning = true
        publishDevices()
    }

    private fun stopDiscovery() {
        if (!scanning) return
        router?.removeCallback(routerCallback)
        scanning = false
    }

    private fun publishDevices() {
        val routes = router?.routes.orEmpty()
            .filter { it.matchesSelector(selector) && !it.isDefault }
            .map {
                mapOf(
                    "id" to it.id,
                    "name" to it.name,
                    "model" to it.description,
                )
            }

        sink?.success(mapOf("type" to "devices", "devices" to routes))
    }

    private fun publishSession(connected: Boolean) {
        sink?.success(
            mapOf(
                "type" to "session",
                "connected" to connected,
                "device" to session?.castDevice?.friendlyName,
            ),
        )
    }

    /**
     * Selects a route, which is what starts a session.
     *
     * There is no "connect" call in the SDK: selecting the route makes the
     * session manager open one, and the answer arrives on [sessionListener].
     * Dart waits for that event rather than for this result.
     */
    private fun connect(id: String?, result: MethodChannel.Result) {
        if (id == null) {
            result.error("no_device", "No device id", null)
            return
        }

        val instance = router ?: MediaRouter.getInstance(activity).also { router = it }
        val route = instance.routes.firstOrNull { it.id == id }

        if (route == null) {
            result.error("unknown_device", "That device is no longer there.", null)
            return
        }

        instance.selectRoute(route)
        result.success(null)
    }

    private fun load(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val client = session?.remoteMediaClient
        if (client == null) {
            result.error("no_session", "Not connected to a device.", null)
            return
        }

        val url = arguments?.get("url") as? String
        if (url == null) {
            result.error("no_url", "Nothing to play", null)
            return
        }

        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
            putString(
                MediaMetadata.KEY_TITLE,
                arguments["title"] as? String ?: "Video",
            )
        }

        val info = MediaInfo.Builder(url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(arguments["contentType"] as? String ?: "video/mp4")
            .setMetadata(metadata)
            .build()

        val request = MediaLoadRequestData.Builder()
            .setMediaInfo(info)
            .setAutoplay(true)
            .setCurrentTime((arguments["positionMs"] as? Number)?.toLong() ?: 0L)
            .build()

        client.load(request).setResultCallback { outcome ->
            if (outcome.status.isSuccess) {
                result.success(null)
            } else {
                // The usual cause is a container the default receiver cannot
                // play — Matroska, most of all. Saying so beats a silent
                // black screen on the television.
                result.error(
                    "load_failed",
                    outcome.status.statusMessage
                        ?: "The device would not play this file. Chromecast "
                        + "handles MP4 and WebM, not MKV.",
                    null,
                )
            }
        }
    }

    private fun remote(
        result: MethodChannel.Result,
        action: (com.google.android.gms.cast.framework.media.RemoteMediaClient) -> Unit,
    ) {
        val client = session?.remoteMediaClient
        if (client == null) {
            result.error("no_session", "Not connected to a device.", null)
            return
        }

        action(client)
        result.success(null)
    }

    private fun status(): Map<String, Any?> {
        val client = session?.remoteMediaClient

        val playback = when (client?.playerState) {
            MediaStatus.PLAYER_STATE_PLAYING -> "playing"
            MediaStatus.PLAYER_STATE_PAUSED -> "paused"
            MediaStatus.PLAYER_STATE_BUFFERING,
            MediaStatus.PLAYER_STATE_LOADING,
            -> "buffering"
            MediaStatus.PLAYER_STATE_IDLE -> "stopped"
            else -> "idle"
        }

        return mapOf(
            "playback" to playback,
            "positionMs" to (client?.approximateStreamPosition ?: 0L),
            // A live stream reports a duration the receiver invents; 0 reads
            // in the UI as "not scrubbable", which is the truth.
            "durationMs" to (client?.streamDuration ?: 0L),
        )
    }

    private fun disconnect() {
        runCatching { castContext?.sessionManager?.endCurrentSession(true) }
        runCatching {
            router?.unselect(MediaRouter.UNSELECT_REASON_STOPPED)
        }
    }
}
