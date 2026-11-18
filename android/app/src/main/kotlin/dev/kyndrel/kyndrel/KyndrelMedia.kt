package dev.kyndrel.kyndrel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.net.URL
import java.util.concurrent.Executors

/**
 * The phone's media controls (task 6.6): a MediaSession (lock screen,
 * Bluetooth and headset buttons, the quick-settings player), its
 * notification, audio focus and "headphones unplugged".
 *
 * Dart sends `update` on `kyndrel/media_session` with the same map as on
 * Windows and macOS; buttons come back as `play`, `pause`, `playPause`,
 * `next`, `previous`, `seekTo` and `seekBy` calls.
 */
object KyndrelMedia {
    const val CHANNEL_ID = "playback"
    const val NOTIFICATION_ID = 1
    const val ACTION_PLAY_PAUSE = "dev.kyndrel.kyndrel.PLAY_PAUSE"
    const val ACTION_PREVIOUS = "dev.kyndrel.kyndrel.PREVIOUS"
    const val ACTION_NEXT = "dev.kyndrel.kyndrel.NEXT"
    const val ACTION_REWIND = "dev.kyndrel.kyndrel.REWIND"
    const val ACTION_FORWARD = "dev.kyndrel.kyndrel.FORWARD"
    private const val SKIP_MS = 10_000

    var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())
    private val artLoader = Executors.newSingleThreadExecutor()

    private var app: Context? = null
    private var session: MediaSession? = null
    private var state: Map<*, *>? = null
    private var artUrl: String? = null
    private var art: Bitmap? = null

    private var focusRequest: AudioFocusRequest? = null
    private var hasFocus = false
    private var pausedByFocus = false
    private var noisyRegistered = false

    /** The notification for the current state, or null when idle. */
    var notification: Notification? = null
        private set

    val isPlaying: Boolean get() = state?.get("playing") == true

    fun send(method: String, argument: Any? = null) {
        main.post { channel?.invokeMethod(method, argument) }
    }

    /** A notification button, a PiP action or a media button. */
    fun handleAction(action: String?) {
        when (action) {
            ACTION_PLAY_PAUSE -> send("playPause")
            ACTION_PREVIOUS -> send("previous")
            ACTION_NEXT -> send("next")
            ACTION_REWIND -> send("seekBy", -SKIP_MS)
            ACTION_FORWARD -> send("seekBy", SKIP_MS)
        }
    }

    fun update(context: Context, map: Map<*, *>) {
        val ctx = context.applicationContext
        app = ctx
        val title = map["title"] as? String
        if (title == null) {
            release(ctx)
            return
        }
        state = map
        val playing = map["playing"] == true
        val s = session ?: MediaSession(ctx, "Kyndrel").also {
            it.setCallback(callback)
            session = it
        }
        s.setMetadata(metadata(map, title))
        s.setPlaybackState(playbackState(map, playing))
        s.isActive = true

        val url = map["artUrl"] as? String
        if (url != artUrl) {
            artUrl = url
            art = null
            if (url != null && url.startsWith("http")) loadArt(url)
        }

        if (playing) {
            requestFocus(ctx)
            registerNoisy(ctx)
        } else {
            unregisterNoisy(ctx)
        }
        showNotification(ctx, playing)
    }

    /** Nothing is open, or the app is closing. */
    fun release(context: Context) {
        val ctx = context.applicationContext
        state = null
        notification = null
        unregisterNoisy(ctx)
        abandonFocus(ctx)
        session?.isActive = false
        session?.release()
        session = null
        ctx.stopService(Intent(ctx, PlaybackService::class.java))
        manager(ctx).cancel(NOTIFICATION_ID)
    }

    // ----------------------------------------------------------- session

    private val callback = object : MediaSession.Callback() {
        override fun onPlay() = send("play")
        override fun onPause() = send("pause")
        override fun onStop() = send("stop")
        override fun onSkipToNext() = send("next")
        override fun onSkipToPrevious() = send("previous")
        override fun onFastForward() = send("seekBy", SKIP_MS)
        override fun onRewind() = send("seekBy", -SKIP_MS)
        override fun onSeekTo(pos: Long) = send("seekTo", pos)
    }

    private fun metadata(map: Map<*, *>, title: String): MediaMetadata {
        val b = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE, title)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, longOf(map["durationMs"]))
        (map["subtitle"] as? String)?.takeIf { it.isNotEmpty() }?.let {
            b.putString(MediaMetadata.METADATA_KEY_ARTIST, it)
            b.putString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE, it)
        }
        art?.let { b.putBitmap(MediaMetadata.METADATA_KEY_ART, it) }
        return b.build()
    }

    private fun playbackState(map: Map<*, *>, playing: Boolean): PlaybackState {
        var actions = PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_SEEK_TO or
            PlaybackState.ACTION_STOP or PlaybackState.ACTION_FAST_FORWARD or
            PlaybackState.ACTION_REWIND
        if (map["canNext"] == true) actions = actions or PlaybackState.ACTION_SKIP_TO_NEXT
        if (map["canPrevious"] == true) {
            actions = actions or PlaybackState.ACTION_SKIP_TO_PREVIOUS
        }
        return PlaybackState.Builder()
            .setActions(actions)
            .setState(
                if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                longOf(map["positionMs"]),
                if (playing) 1f else 0f,
            )
            .build()
    }

    private fun longOf(v: Any?): Long = (v as? Number)?.toLong() ?: 0L

    private fun loadArt(url: String) {
        artLoader.execute {
            val bitmap = try {
                URL(url).openStream().use { BitmapFactory.decodeStream(it) }
            } catch (e: Exception) {
                null
            } ?: return@execute
            main.post {
                if (artUrl != url) return@post
                art = bitmap
                val ctx = app ?: return@post
                state?.let { update(ctx, it) }
            }
        }
    }

    // ------------------------------------------------------ notification

    private fun manager(ctx: Context) =
        ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun showNotification(ctx: Context, playing: Boolean) {
        val n = buildNotification(ctx, playing)
        notification = n
        val service = Intent(ctx, PlaybackService::class.java)
        if (playing) {
            // Keeps playing with the screen off or another app in front.
            try {
                if (Build.VERSION.SDK_INT >= 26) {
                    ctx.startForegroundService(service)
                } else {
                    ctx.startService(service)
                }
            } catch (e: Exception) {
                // Not allowed from the background right now: still show it.
                manager(ctx).notify(NOTIFICATION_ID, n)
            }
        } else {
            PlaybackService.current?.leaveForeground()
            manager(ctx).notify(NOTIFICATION_ID, n)
        }
    }

    private fun buildNotification(ctx: Context, playing: Boolean): Notification {
        val m = state ?: emptyMap<Any, Any>()
        if (Build.VERSION.SDK_INT >= 26) {
            manager(ctx).createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    ctx.getString(R.string.playback_channel),
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { setShowBadge(false) },
            )
        }
        val b = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(ctx, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(ctx)
        }
        val open = PendingIntent.getActivity(
            ctx, 0,
            Intent(ctx, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val actions = mutableListOf<Notification.Action>()
        val compact = mutableListOf<Int>()
        fun add(icon: Int, label: Int, action: String, inCompact: Boolean) {
            if (inCompact) compact += actions.size
            actions += Notification.Action.Builder(
                Icon.createWithResource(ctx, icon),
                ctx.getString(label),
                actionIntent(ctx, action),
            ).build()
        }
        if (m["canPrevious"] == true) {
            add(R.drawable.ic_skip_previous, R.string.previous, ACTION_PREVIOUS, false)
        }
        add(R.drawable.ic_replay_10, R.string.rewind, ACTION_REWIND, true)
        if (playing) {
            add(R.drawable.ic_pause, R.string.pause, ACTION_PLAY_PAUSE, true)
        } else {
            add(R.drawable.ic_play, R.string.play, ACTION_PLAY_PAUSE, true)
        }
        add(R.drawable.ic_forward_10, R.string.forward, ACTION_FORWARD, true)
        if (m["canNext"] == true) {
            add(R.drawable.ic_skip_next, R.string.next, ACTION_NEXT, false)
        }

        val style = Notification.MediaStyle().setShowActionsInCompactView(*compact.toIntArray())
        session?.let { style.setMediaSession(it.sessionToken) }
        b.setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(m["title"] as? String)
            .setContentText(m["subtitle"] as? String)
            .setContentIntent(open)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(playing)
            .setShowWhen(false)
            .setStyle(style)
        art?.let { b.setLargeIcon(it) }
        actions.forEach { b.addAction(it) }
        return b.build()
    }

    fun actionIntent(ctx: Context, action: String): PendingIntent = PendingIntent.getBroadcast(
        ctx,
        action.hashCode(),
        Intent(ctx, MediaActionReceiver::class.java).setAction(action),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    // -------------------------------------------------------- audio focus

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS -> {
                // Another app started playing: stop for good.
                pausedByFocus = false
                hasFocus = false
                send("pause")
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                // A call or an assistant: resume afterwards.
                if (isPlaying) {
                    pausedByFocus = true
                    send("pause")
                }
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                hasFocus = true
                if (pausedByFocus) {
                    pausedByFocus = false
                    send("play")
                }
            }
            // LOSS_TRANSIENT_CAN_DUCK: Android 8+ lowers the volume itself.
        }
    }

    private fun audio(ctx: Context) =
        ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun requestFocus(ctx: Context) {
        pausedByFocus = false
        if (hasFocus) return
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            val request = focusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                        .build(),
                )
                .setOnAudioFocusChangeListener(focusListener)
                .build()
                .also { focusRequest = it }
            audio(ctx).requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audio(ctx).requestAudioFocus(
                focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN,
            )
        }
        hasFocus = granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonFocus(ctx: Context) {
        if (!hasFocus) return
        hasFocus = false
        pausedByFocus = false
        if (Build.VERSION.SDK_INT >= 26) {
            focusRequest?.let { audio(ctx).abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audio(ctx).abandonAudioFocus(focusListener)
        }
    }

    // ------------------------------------------------ headphones unplugged

    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) send("pause")
        }
    }

    private fun registerNoisy(ctx: Context) {
        if (noisyRegistered) return
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) {
            ctx.registerReceiver(noisy, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            ctx.registerReceiver(noisy, filter)
        }
        noisyRegistered = true
    }

    private fun unregisterNoisy(ctx: Context) {
        if (!noisyRegistered) return
        try {
            ctx.unregisterReceiver(noisy)
        } catch (e: IllegalArgumentException) {
            // Already gone.
        }
        noisyRegistered = false
    }
}

/** Notification and picture-in-picture buttons. */
class MediaActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        KyndrelMedia.handleAction(intent.action)
    }
}
