package dev.icedtea.mplayer

import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var mediaStore: MediaStoreChannel? = null
    private var saf: SafChannel? = null
    private var incoming: IntentChannel? = null
    private var pip: PipChannel? = null
    private var nowPlaying: NowPlayingChannel? = null
    private var cast: CastChannel? = null

    /**
     * True when Android rebuilt this activity after killing the process.
     *
     * The task record keeps the intent that originally started the activity
     * and hands it back on restore, so without the flag returning to mPlayer
     * from recents replays whatever file was opened days ago. Assigned before
     * `super.onCreate`, which is what calls [configureFlutterEngine].
     */
    private var restored = false

    override fun onCreate(savedInstanceState: Bundle?) {
        restored = savedInstanceState != null
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val media = MediaStoreChannel(this)
        mediaStore = media

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MediaStoreChannel.CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "videosIn" -> media.handleVideosIn(call.argument("bucketId"), result)
                else -> media.handle(call.method, result)
            }
        }

        val documents = SafChannel(this)
        saf = documents

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SafChannel.CHANNEL,
        ).setMethodCallHandler { call, result ->
            documents.handle(call.method, call.arguments as? Map<*, *>, result)
        }

        val intents = IntentChannel(this)
        incoming = intents

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            IntentChannel.CHANNEL,
        ).setMethodCallHandler { call, result ->
            intents.handle(call.method, result)
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            IntentChannel.EVENTS,
        ).setStreamHandler(intents.streamHandler())

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

        // The intent that started the activity. Offered here, after the
        // channels exist, so a cold start has somewhere to put the file.
        if (!restored) intents.offer(intent)
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
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // launchMode is singleTask, so every "Open with" after the first
        // arrives here rather than through a second activity.
        incoming?.offer(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        // Let the channel claim its own request before Flutter's plugins see
        // it; returning early would swallow results other plugins wait for.
        val handled = mediaStore?.onRequestPermissionsResult(
            requestCode, permissions, grantResults,
        ) ?: false

        if (!handled) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val handled = saf?.onActivityResult(requestCode, resultCode, data) ?: false

        if (!handled) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
