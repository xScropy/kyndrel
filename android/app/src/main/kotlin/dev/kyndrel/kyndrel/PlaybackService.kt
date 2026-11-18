package dev.kyndrel.kyndrel

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps Kyndrel alive while it plays with the screen off or another app in
 * front (task 6.6). It only holds the media notification in the
 * foreground; the player itself lives in the Flutter engine.
 */
class PlaybackService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        current = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val n = KyndrelMedia.notification
        if (n == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(
                KyndrelMedia.NOTIFICATION_ID, n,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(KyndrelMedia.NOTIFICATION_ID, n)
        }
        return START_NOT_STICKY
    }

    /** Paused: the notification stays (and can be swiped away), the
     *  service goes. */
    fun leaveForeground() {
        stopForeground(STOP_FOREGROUND_DETACH)
        stopSelf()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Swiped out of recents: stop playing.
        KyndrelMedia.release(this)
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }

    companion object {
        var current: PlaybackService? = null
            private set
    }
}
