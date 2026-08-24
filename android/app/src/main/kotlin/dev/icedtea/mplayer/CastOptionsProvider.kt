package dev.icedtea.mplayer

import android.content.Context
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.framework.CastOptions
import com.google.android.gms.cast.framework.OptionsProvider
import com.google.android.gms.cast.framework.SessionProvider

/**
 * Configuration the Cast SDK reads at startup.
 *
 * Required by the framework and found by name: the class is named in a
 * `meta-data` entry in the manifest, which is the only reference to it — so it
 * has to stay public with a no-argument constructor, and nothing here may be
 * renamed without editing the manifest too.
 *
 * The **default media receiver** is used deliberately. A custom receiver would
 * mean registering an application with Google and hosting a web receiver, for
 * no gain: mPlayer sends a plain URL and drives the standard transport.
 *
 * That receiver decides what plays. It handles MP4/H.264 and WebM, and does
 * **not** handle Matroska — which is most of what this player exists for. A
 * rejected load is reported to Dart as an error rather than papered over,
 * because the fix is transcoding, which is a server's job.
 */
class CastOptionsProvider : OptionsProvider {

    override fun getCastOptions(context: Context): CastOptions {
        return CastOptions.Builder()
            .setReceiverApplicationId(
                CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID,
            )
            // mPlayer draws its own device picker and its own transport, so
            // none of the SDK's UI is wanted — leaving it enabled would put a
            // second, differently styled controller in the notification shade
            // next to the one PlaybackService already posts.
            .setEnableReconnectionService(false)
            .setStopReceiverApplicationWhenEndingSession(true)
            .build()
    }

    override fun getAdditionalSessionProviders(
        context: Context,
    ): MutableList<SessionProvider>? = null
}
