package dev.inkora.inkora

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import io.flutter.FlutterInjector
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** One small offline tile, prepared off the UI thread only when requested. */
internal object EbookPaperTexture {
    private val lock = Mutex()
    private var cached: String? = null
    private var generation = 0
    fun trimMemory() { cached = null; generation++ }
    var decodeCount = 0; private set
    var tileWidth = 0; private set
    var tileHeight = 0; private set
    val encodedLength: Int get() = cached?.length ?: 0

    // The Flutter canvas uses the exact same prepared tile as native EPUB.
    suspend fun bytes(context: Context): ByteArray = withContext(Dispatchers.IO) {
        Base64.decode(url(context).substringAfter(','), Base64.NO_WRAP)
    }

    suspend fun url(context: Context): String = lock.withLock {
        val revision = generation
        cached ?: withContext(Dispatchers.IO) {
            val path = FlutterInjector.instance().flutterLoader()
                .getLookupKeyForAsset("assets/reader/paper.png")
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            context.assets.open(path).use { BitmapFactory.decodeStream(it, null, bounds) }
            require(bounds.outWidth in 1..2048 && bounds.outHeight in 1..2048)
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 512) sample *= 2
            val options = BitmapFactory.Options().apply { inSampleSize = sample; inScaled = false }
            val decoded = context.assets.open(path).use {
                requireNotNull(BitmapFactory.decodeStream(it, null, options))
            }
            val extent = maxOf(decoded.width, decoded.height)
            val bitmap = if (extent > 512) Bitmap.createScaledBitmap(decoded,
                maxOf(1, decoded.width * 512 / extent),
                maxOf(1, decoded.height * 512 / extent), true).also { decoded.recycle() }
                else decoded
            tileWidth = bitmap.width
            tileHeight = bitmap.height
            decodeCount++
            // Prepare neutral translucent grain once, off the UI thread. The
            // selected Readium color stays visible through the tile, including
            // dark colors; no per-frame filter or color-specific cache is needed.
            val prepared = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
            val pixels = IntArray(bitmap.width * bitmap.height)
            bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
            fun luminance(pixel: Int): Int =
                (((pixel ushr 16) and 255) * 54 + ((pixel ushr 8) and 255) * 183 + (pixel and 255) * 19) / 256
            val mean = pixels.sumOf { luminance(it).toLong() }.toInt() / pixels.size
            for (index in pixels.indices) {
                val delta = luminance(pixels[index]) - mean
                val alpha = minOf(16, kotlin.math.abs(delta) * 2)
                pixels[index] = (alpha shl 24) or (if (delta > 0) 0x00ffffff else 0)
            }
            val bytes = ByteArrayOutputStream()
            try {
                prepared.setPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
                prepared.compress(Bitmap.CompressFormat.PNG, 100, bytes)
            } finally { bitmap.recycle(); prepared.recycle() }
            require(bytes.size() <= 256 * 1024) { "Paper tile PNG exceeds bound: ${bytes.size()} bytes" }
            "data:image/png;base64," + Base64.encodeToString(bytes.toByteArray(), Base64.NO_WRAP)
        }.also { if (revision == generation) cached = it }
    }
}
