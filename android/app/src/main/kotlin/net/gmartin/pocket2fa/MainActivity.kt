package net.gmartin.pocket2fa

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "net.gmartin.pocket2fa/incoming_image"
        private const val STAGING_DIR = "incoming_qr_android"

        /**
         * Must stay aligned with IncomingImageProcessor.maxFileBytes in Dart.
         * Shared images above this size are rejected before decoding.
         */
        private const val MAX_BYTES = 32L * 1024L * 1024L

        /** Staging cleanup is once per process, not once per activity. */
        private var stagingCleaned = false
    }

    private class TooLargeException : Exception()
    private class UnsupportedException(message: String) : Exception(message)

    private val mainHandler = Handler(Looper.getMainLooper())
    private val copyExecutor = Executors.newSingleThreadExecutor()

    private var channel: MethodChannel? = null
    private var clientReady = false
    private var pendingLaunchIntent: Intent? = null
    private var pendingDescriptor: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // A previous process may have died between staging a share and
        // processing it. Remove those files before handling a new launch.
        if (!stagingCleaned) {
            cleanStagingDir()
            stagingCleaned = true
        }

        // A share that launched the process is held until Dart registers its
        // handler and calls clientReady.
        shareIntentOf(intent)?.let { pendingLaunchIntent = it }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "clientReady" -> {
                    clientReady = true
                    result.success(null)
                    flushPendingDescriptor()
                    flushPendingLaunchIntent()
                }

                else -> result.notImplemented()
            }
        }
        channel = methodChannel
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val share = shareIntentOf(intent) ?: return
        if (!clientReady || channel == null) {
            pendingLaunchIntent = share
        } else {
            handleShare(share)
        }
    }

    private fun shareIntentOf(intent: Intent?): Intent? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE -> intent
            else -> null
        }
    }

    private fun flushPendingLaunchIntent() {
        val launch = pendingLaunchIntent ?: return
        pendingLaunchIntent = null
        handleShare(launch)
    }

    private fun flushPendingDescriptor() {
        val descriptor = pendingDescriptor ?: return
        pendingDescriptor = null
        channel?.invokeMethod("sharedImage", descriptor)
    }

    private fun handleShare(intent: Intent) {
        val streams = extractStreams(intent)
        if (streams.isEmpty()) {
            emitRejection("unsupported")
            return
        }
        if (streams.size > 1) {
            // Reject before copying anything: a multi-image intake must never
            // create a partial account.
            emitRejection("multiple")
            return
        }

        val uri = streams.first()
        copyExecutor.execute {
            val descriptor = try {
                stageImage(uri, intent.type)
            } catch (e: TooLargeException) {
                Log.w(TAG, "Shared image exceeds the 32 MiB limit")
                rejection("tooLarge")
            } catch (e: UnsupportedException) {
                Log.w(TAG, "Shared content is not a supported image: ${e.message}")
                rejection("unsupported")
            } catch (e: Exception) {
                Log.w(TAG, "Could not stage shared image: ${e.message}")
                rejection("unreadable")
            }
            mainHandler.post { emit(descriptor) }
        }
    }

    /**
     * Reads ACTION_SEND's single stream, ACTION_SEND_MULTIPLE's list form and
     * any ClipData items, de-duplicating the same Uri.
     */
    private fun extractStreams(intent: Intent): List<Uri> {
        val streams = LinkedHashSet<Uri>()

        @Suppress("DEPRECATION")
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                ?.let { streams.addAll(it) }
        } else {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                ?.let { streams.add(it) }
        }

        intent.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) {
                clip.getItemAt(index).uri?.let { streams.add(it) }
            }
        }

        return streams.toList()
    }

    private fun stageImage(uri: Uri, fallbackMimeType: String?): Map<String, Any?> {
        val mimeType = contentResolver.getType(uri) ?: fallbackMimeType
        if (mimeType == null || !mimeType.startsWith("image/")) {
            throw UnsupportedException("mime=$mimeType")
        }

        val displayName = queryDisplayName(uri) ?: "image"
        val extension = extensionForMimeType(mimeType)
        val directory = File(cacheDir, STAGING_DIR).apply { mkdirs() }
        val target = File(directory, "${UUID.randomUUID()}.$extension")

        try {
            val input = contentResolver.openInputStream(uri)
                ?: throw IOException("No input stream for shared image")
            input.use { stream ->
                target.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    var copied = 0L
                    while (true) {
                        val read = stream.read(buffer)
                        if (read == -1) break
                        copied += read
                        if (copied > MAX_BYTES) throw TooLargeException()
                        output.write(buffer, 0, read)
                    }
                }
            }
        } catch (e: Exception) {
            target.delete()
            throw e
        }

        return mapOf(
            "kind" to "image",
            "path" to target.absolutePath,
            "mimeType" to mimeType,
            "name" to displayName,
        )
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not read display name: ${e.message}")
            null
        }
    }

    private fun extensionForMimeType(mimeType: String): String {
        return when (mimeType.lowercase()) {
            "image/jpeg", "image/jpg" -> "jpg"
            "image/png" -> "png"
            "image/webp" -> "webp"
            "image/gif" -> "gif"
            "image/bmp", "image/x-ms-bmp" -> "bmp"
            "image/heic" -> "heic"
            "image/heif" -> "heif"
            "image/avif" -> "avif"
            else -> "img"
        }
    }

    private fun cleanStagingDir() {
        try {
            File(cacheDir, STAGING_DIR).listFiles()?.forEach { it.deleteRecursively() }
        } catch (e: Exception) {
            Log.w(TAG, "Could not clean incoming share cache: ${e.message}")
        }
    }

    private fun rejection(reason: String): Map<String, Any?> =
        mapOf("kind" to "rejected", "reason" to reason)

    private fun emitRejection(reason: String) {
        emit(rejection(reason))
    }

    private fun emit(descriptor: Map<String, Any?>) {
        val activeChannel = channel
        if (!clientReady || activeChannel == null) {
            pendingDescriptor = descriptor
            return
        }
        activeChannel.invokeMethod("sharedImage", descriptor)
    }

    override fun onDestroy() {
        copyExecutor.shutdown()
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }

    // Override onActivityResult to handle null bundles gracefully
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        try {
            super.onActivityResult(requestCode, resultCode, data)
        } catch (e: NullPointerException) {
            // Handle null pointer exception gracefully
            android.util.Log.w("MainActivity", "NullPointerException in onActivityResult: ${e.message}")
        }
    }
}
