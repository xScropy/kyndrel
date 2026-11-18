package dev.kyndrel.kyndrel

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * Android glue for the Dart side (tasks 6.1, 6.2):
 * - `kyndrel/open_external`: open a link in the browser.
 * - `kyndrel/open_file`: files from "Open with" / share; same protocol as
 *   macOS (`pending` at start, then `open` calls), with {uri, name} maps.
 * - `kyndrel/android_media`: document picker, video permission, MediaStore.
 * - `kyndrel/frames`: seek-preview frames (task 6.4).
 */
class MainActivity : FlutterActivity() {
    private var openChannel: MethodChannel? = null
    private val pending = mutableListOf<Map<String, String>>()
    private var pickResult: MethodChannel.Result? = null
    private var accessResult: MethodChannel.Result? = null

    // Preview frames are decoded off the main thread, one at a time, with
    // one retriever kept open for the current file.
    private val frameExecutor = Executors.newSingleThreadExecutor()
    private var retriever: MediaMetadataRetriever? = null
    private var retrieverSource: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A cold start "Open with": keep until Dart asks for `pending`.
        if (savedInstanceState == null) pending += filesFrom(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val files = filesFrom(intent)
        if (files.isEmpty()) return
        val channel = openChannel
        if (channel == null) pending += files else channel.invokeMethod("open", files)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "kyndrel/open_external").setMethodCallHandler { call, result ->
            if (call.method != "open") return@setMethodCallHandler result.notImplemented()
            val target = call.arguments as? String
                ?: return@setMethodCallHandler result.error("args", "a URL is needed", null)
            try {
                startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(target))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(null)
            } catch (e: ActivityNotFoundException) {
                result.error("no_app", "No app can open $target", null)
            }
        }

        openChannel = MethodChannel(messenger, "kyndrel/open_file").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "pending" -> {
                        result.success(pending.toList())
                        pending.clear()
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(messenger, "kyndrel/frames").setMethodCallHandler { call, result ->
            if (call.method != "frame") return@setMethodCallHandler result.notImplemented()
            val source = call.argument<String>("source")
            val path = call.argument<String>("path")
            val ms = (call.argument<Number>("ms") ?: 0).toLong()
            val width = (call.argument<Number>("width") ?: 480).toInt()
            if (source == null || path == null) {
                return@setMethodCallHandler result.error("args", "source and path", null)
            }
            frameExecutor.execute {
                val ok = try {
                    writeFrame(source, ms, width, path)
                } catch (e: Exception) {
                    false
                }
                runOnUiThread { result.success(ok) }
            }
        }

        MethodChannel(messenger, "kyndrel/android_media").setMethodCallHandler { call, result ->
            when (call.method) {
                "pick" -> pick(call.argument<Boolean>("multiple") ?: false, result)
                "requestVideoAccess" -> requestVideoAccess(result)
                "videos" -> result.success(queryVideos())
                else -> result.notImplemented()
            }
        }
    }

    // ------------------------------------------------------------ intents

    private fun filesFrom(intent: Intent?): List<Map<String, String>> {
        if (intent == null) return emptyList()
        val uris = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { uris += it }
            Intent.ACTION_SEND -> {
                streamExtra(intent)?.let { uris += it }
                // A shared link (e.g. from a browser).
                intent.getStringExtra(Intent.EXTRA_TEXT)
                    ?.let { Regex("""https?://\S+""").find(it)?.value }
                    ?.let { uris += Uri.parse(it) }
            }
            Intent.ACTION_SEND_MULTIPLE -> uris += streamListExtra(intent)
        }
        return uris.map { file(it) }
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    @Suppress("DEPRECATION")
    private fun streamListExtra(intent: Intent): List<Uri> =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        } ?: emptyList()

    /** {uri, name}: the display name, since content:// URIs are opaque. */
    private fun file(uri: Uri): Map<String, String> {
        var name = uri.lastPathSegment ?: uri.toString()
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { c -> if (c.moveToFirst() && !c.isNull(0)) name = c.getString(0) }
            } catch (e: Exception) {
                // Some providers refuse queries; the URI's last part will do.
            }
        }
        val source = if (uri.scheme == "file") uri.path ?: uri.toString() else uri.toString()
        return mapOf("uri" to source, "name" to name)
    }

    // ------------------------------------------------------------ picker

    private fun pick(multiple: Boolean, result: MethodChannel.Result) {
        if (pickResult != null) return result.error("busy", "A picker is already open", null)
        pickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("video/*", "audio/*", "application/x-mpegurl"))
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, PICK_REQUEST)
    }

    @Deprecated("Activity result API needs a ComponentActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_REQUEST) return
        val result = pickResult ?: return
        pickResult = null
        if (resultCode != RESULT_OK || data == null) return result.success(emptyList<Any>())
        val uris = mutableListOf<Uri>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) uris += clip.getItemAt(i).uri
        } else {
            data.data?.let { uris += it }
        }
        for (uri in uris) {
            // Keep access across restarts, so history and resume work.
            try {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (e: SecurityException) {
                // Not persistable from this provider: works for this session.
            }
        }
        result.success(uris.map { file(it) })
    }

    // ------------------------------------------------------------ media library

    private val videoPermission =
        if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_VIDEO
        else Manifest.permission.READ_EXTERNAL_STORAGE

    private fun requestVideoAccess(result: MethodChannel.Result) {
        if (checkSelfPermission(videoPermission) == PackageManager.PERMISSION_GRANTED) {
            return result.success(true)
        }
        if (accessResult != null) return result.error("busy", "Already asking", null)
        accessResult = result
        requestPermissions(arrayOf(videoPermission), ACCESS_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != ACCESS_REQUEST) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        accessResult?.success(granted)
        accessResult = null
    }

    private fun queryVideos(): List<Map<String, Any>> {
        if (checkSelfPermission(videoPermission) != PackageManager.PERMISSION_GRANTED) {
            return emptyList()
        }
        val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val columns = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_ADDED,
        )
        val out = mutableListOf<Map<String, Any>>()
        contentResolver.query(
            collection, columns, null, null,
            "${MediaStore.Video.Media.DATE_ADDED} DESC",
        )?.use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0)
                out += mapOf(
                    "uri" to ContentUris.withAppendedId(collection, id).toString(),
                    "name" to (c.getString(1) ?: "$id"),
                    "folder" to (c.getString(2) ?: ""),
                    "durationMs" to c.getLong(3),
                    "size" to c.getLong(4),
                    "addedS" to c.getLong(5),
                )
            }
        }
        return out
    }

    // ------------------------------------------------------------ frames

    private fun retrieverFor(source: String): MediaMetadataRetriever {
        retriever?.let { if (retrieverSource == source) return it }
        retriever?.release()
        val r = MediaMetadataRetriever()
        if (source.startsWith("content://")) {
            r.setDataSource(this, Uri.parse(source))
        } else {
            r.setDataSource(source.removePrefix("file://"))
        }
        retriever = r
        retrieverSource = source
        return r
    }

    private fun writeFrame(source: String, ms: Long, width: Int, path: String): Boolean {
        val r = retrieverFor(source)
        val us = ms * 1000
        val option = MediaMetadataRetriever.OPTION_CLOSEST_SYNC
        val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
        val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
        val bitmap: Bitmap = (
            if (Build.VERSION.SDK_INT >= 27 && w > 0 && h > 0) {
                r.getScaledFrameAtTime(us, option, width, maxOf(1, width * h / w))
            } else {
                r.getFrameAtTime(us, option)?.let { full ->
                    if (full.width <= width) {
                        full
                    } else {
                        Bitmap.createScaledBitmap(
                            full, width, maxOf(1, width * full.height / full.width), true,
                        ).also { full.recycle() }
                    }
                }
            }
        ) ?: return false
        File(path).parentFile?.mkdirs()
        FileOutputStream(path).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 80, it) }
        bitmap.recycle()
        return true
    }

    override fun onDestroy() {
        frameExecutor.shutdown()
        retriever?.release()
        retriever = null
        super.onDestroy()
    }

    companion object {
        private const val PICK_REQUEST = 4201
        private const val ACCESS_REQUEST = 4202
    }
}
