package dev.icedtea.mplayer

import android.app.UiModeManager
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Six channels: three for the player, one for installing updates, one for
 * the downloads' foreground service, and one that says whether this is a
 * television.
 *
 * Gone with the device library: [MediaStoreChannel] (the system media index),
 * `SafChannel` (folders the user granted explicitly) and `IntentChannel` (the
 * VIEW and SEND intents that carried a file in). mPlayer reads none of the
 * user's own files any more — it plays what a media server gives it.
 *
 * What stays belongs to the player, which stays: picture in picture, the
 * media notification behind the foreground playback service, and the Cast
 * SDK. As with every channel here, **Kotlin decides nothing** — every button
 * and every window event is forwarded to Dart, which owns the player.
 */
class MainActivity : FlutterActivity() {

    private var pip: PipChannel? = null
    private var nowPlaying: NowPlayingChannel? = null
    private var cast: CastChannel? = null
    private var downloads: DownloadChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val picture = PipChannel(this)
        pip = picture

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PipChannel.CHANNEL,
        ).setMethodCallHandler { call, result ->
            picture.handle(call.method, call.arguments as? Map<*, *>, result)
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PipChannel.EVENTS,
        ).setStreamHandler(picture.streamHandler())

        val playing = NowPlayingChannel(this)
        nowPlaying = playing

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NowPlayingChannel.CHANNEL,
        ).setMethodCallHandler { call, result ->
            playing.handle(call.method, call.arguments as? Map<*, *>, result)
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NowPlayingChannel.EVENTS,
        ).setStreamHandler(playing.streamHandler())

        val chromecast = CastChannel(this)
        cast = chromecast

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CastChannel.CHANNEL,
        ).setMethodCallHandler { call, result ->
            chromecast.handle(call.method, call.arguments as? Map<*, *>, result)
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CastChannel.EVENTS,
        ).setStreamHandler(chromecast.streamHandler())

        val updates = UpdateChannel(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UpdateChannel.CHANNEL,
        ).setMethodCallHandler { call, result ->
            updates.handle(call.method, call.arguments as? Map<*, *>, result)
        }

        val transfers = DownloadChannel(this)
        downloads = transfers
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DownloadChannel.CHANNEL,
        ).setMethodCallHandler { call, result ->
            transfers.handle(call.method, call.arguments as? Map<*, *>, result)
        }

        // A fact, not a decision: Dart chooses what a television gets.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.icedtea.mplayer/device",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTelevision" -> result.success(isTelevision())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Leanback is what Android TV devices declare; the UI mode catches a box
     * whose vendor left the feature out but still runs the TV launcher.
     */
    private fun isTelevision(): Boolean {
        if (packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)) {
            return true
        }
        val modes = getSystemService(UI_MODE_SERVICE) as? UiModeManager
        return modes?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
    }

    /**
     * Home or Recents. On API 26-30 this is the only chance to enter picture
     * in picture; 31 and up do it from the params instead.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        pip?.onUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pip?.onModeChanged(isInPictureInPictureMode)
    }

    override fun onDestroy() {
        pip?.dispose()
        pip = null
        // The notification outliving the engine would leave buttons that
        // reach nothing, so the service goes down with the activity.
        nowPlaying?.dispose()
        nowPlaying = null
        // An active scan left running would keep costing battery after the
        // player is gone.
        cast?.dispose()
        cast = null
        // The downloads run in this engine; a notification left behind would
        // claim progress nothing is making.
        downloads?.dispose()
        downloads = null
        super.onDestroy()
    }
}
