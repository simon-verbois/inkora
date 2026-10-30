package dev.inkora.inkora

import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Shader
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.Drawable
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.webkit.WebView

/** Page-attached geometry without DOM rules, per-frame JavaScript or timers. */
internal class EbookSpreadDivider(val view: View, private val onSizeChanged: () -> Unit) {
    private var lastWidth = -1
    private var lastHeight = -1
    private class Page(val view: WebView) {
        val location = IntArray(2)
        val lines = arrayOf(Rect(), Rect())
        var gradient: LinearGradient? = null
        var gradientTop = Int.MIN_VALUE
        var gradientBottom = Int.MIN_VALUE
        var gradientColor = 0
    }
    private val origin = IntArray(2)
    private var pages = emptyList<Page>()
    private val paint = Paint()
    private var enabled = false
    var gradientBuilds = 0; private set
    var color: Int = 0xff252320.toInt()
        set(value) {
            if (field == value) return
            field = value
            line.invalidateSelf()
        }
    val alpha: Int get() = if (enabled) 46 else 0
    val segments: List<Rect> get() = pages.flatMap { it.lines.asList() }.filter { !it.isEmpty }
    val line: Drawable = object : Drawable() {
        override fun draw(canvas: Canvas) {
            if (!enabled) return
            paint.alpha = 255
            for (page in pages) {
                paint.shader = page.gradient
                for (rect in page.lines) if (!rect.isEmpty) canvas.drawRect(rect, paint)
            }
        }
        override fun setAlpha(alpha: Int) = Unit
        override fun setColorFilter(filter: ColorFilter?) = Unit
        @Deprecated("Drawable opacity is no longer used")
        override fun getOpacity() = PixelFormat.TRANSLUCENT
    }
    private val layout = ViewTreeObserver.OnGlobalLayoutListener {
        if (lastWidth != view.width || lastHeight != view.height) {
            lastWidth = view.width
            lastHeight = view.height
            onSizeChanged()
        }
        if (enabled) { discover(); update() }
    }
    private val draw = ViewTreeObserver.OnPreDrawListener {
        if (enabled) update()
        true
    }

    init {
        view.overlay.add(line)
        view.viewTreeObserver.addOnGlobalLayoutListener(layout)
        view.viewTreeObserver.addOnPreDrawListener(draw)
    }

    private fun discover() {
        val found = mutableListOf<WebView>()
        fun visit(child: View) {
            if (EbookBookPagination.isCounterView(child)) return
            if (child is WebView) found.add(child)
            else if (child is ViewGroup) for (i in 0 until child.childCount) visit(child.getChildAt(i))
        }
        visit(view)
        if (found.size != pages.size || found.indices.any { found[it] !== pages[it].view }) {
            pages = found.map { Page(it) }
            line.invalidateSelf()
        }
    }

    private fun update() {
        line.setBounds(0, 0, view.width, view.height)
        view.getLocationInWindow(origin)
        var changed = false
        for (page in pages) {
            val web = page.view
            web.getLocationInWindow(page.location)
            val x = page.location[0] - origin[0]
            val y = page.location[1] - origin[1]
            val width = web.width
            val first = x + width / 2 - if (width > 0) Math.floorMod(web.scrollX, width) else 0
            val topEdge = maxOf(0, y)
            val bottomEdge = minOf(view.height, y + web.height)
            if (topEdge < bottomEdge && (page.gradientTop != topEdge ||
                page.gradientBottom != bottomEdge || page.gradientColor != color)) {
                page.gradientTop = topEdge
                page.gradientBottom = bottomEdge
                page.gradientColor = color
                val transparent = color and 0x00ffffff
                val ink = transparent or (46 shl 24)
                gradientBuilds++
                page.gradient = LinearGradient(0f, topEdge.toFloat(), 0f, bottomEdge.toFloat(),
                    intArrayOf(transparent, ink, ink, transparent),
                    floatArrayOf(0f, .12f, .88f, 1f), Shader.TileMode.CLAMP)
                changed = true
            }
            for (i in 0..1) {
                val left = first + i * width
                val top = maxOf(0, y)
                val bottom = minOf(view.height, y + web.height)
                val visible = web.isShown && width > 0 && top < bottom &&
                    left >= maxOf(0, x) && left < minOf(view.width, x + width)
                val rect = page.lines[i]
                if (visible) {
                    if (rect.left != left || rect.top != top || rect.right != left + 1 || rect.bottom != bottom) {
                        rect.set(left, top, left + 1, bottom)
                        changed = true
                    }
                } else if (!rect.isEmpty) { rect.setEmpty(); changed = true }
            }
        }
        if (changed) line.invalidateSelf()
    }

    fun show(visible: Boolean) {
        if (!enabled && !visible) return
        enabled = visible
        if (visible) { discover(); update() }
        else for (page in pages) for (rect in page.lines) rect.setEmpty()
        line.invalidateSelf()
    }

    fun close() {
        val observer = view.viewTreeObserver
        if (observer.isAlive) {
            observer.removeOnGlobalLayoutListener(layout)
            observer.removeOnPreDrawListener(draw)
        }
        view.overlay.remove(line)
        pages = emptyList()
    }
}
