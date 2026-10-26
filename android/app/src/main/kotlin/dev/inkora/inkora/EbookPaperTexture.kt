package dev.inkora.inkora

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
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

    suspend fun url(context: Context): String = lock.withLock {
        val revision = generation
        cached ?: withContext(Dispatchers.IO) {
            val path = FlutterInjector.instance().flutterLoader()
                .getLookupKeyForAsset("assets/reader/paper.png")
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            context.assets.open(path).use { BitmapFactory.decodeStream(it, null, bounds) }
            require(bounds.outWidth in 1..2048 && bounds.outHeight in 1..2048)
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 256) sample *= 2
            val options = BitmapFactory.Options().apply { inSampleSize = sample; inScaled = false }
            val bitmap = context.assets.open(path).use {
                requireNotNull(BitmapFactory.decodeStream(it, null, options))
            }
            tileWidth = bitmap.width
            tileHeight = bitmap.height
            decodeCount++
            // Bake a faint paper wash once, rather than filtering each frame.
            val prepared = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
            val bytes = ByteArrayOutputStream()
            try {
                Canvas(prepared).apply {
                    drawColor(0xfff8f7f2.toInt())
                    drawBitmap(bitmap, 0f, 0f, Paint().apply { alpha = 140 })
                }
                prepared.compress(Bitmap.CompressFormat.PNG, 100, bytes)
            } finally { bitmap.recycle(); prepared.recycle() }
            require(bytes.size() <= 96 * 1024)
            "data:image/png;base64," + Base64.encodeToString(bytes.toByteArray(), Base64.NO_WRAP)
        }.also { if (revision == generation) cached = it }
    }
}
