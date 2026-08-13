package dev.icedtea.mplayer

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var mediaStore: MediaStoreChannel? = null
    private var saf: SafChannel? = null

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
