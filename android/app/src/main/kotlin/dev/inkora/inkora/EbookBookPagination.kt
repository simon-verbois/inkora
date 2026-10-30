package dev.inkora.inkora

import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import dk.nota.flutterreadium.ReaderFontStyle
import dk.nota.flutterreadium.ReadiumReader
import dk.nota.flutterreadium.fragments.EpubReaderFragment
import dk.nota.flutterreadium.models.EpubReaderViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeout
import org.json.JSONObject
import org.json.JSONTokener
import org.readium.r2.navigator.epub.EpubNavigatorFragment
import org.readium.r2.navigator.epub.css.FontStyle
import org.readium.r2.navigator.epub.css.FontWeight
import org.readium.r2.navigator.preferences.FontFamily
import org.readium.r2.shared.ExperimentalReadiumApi
import org.readium.r2.shared.publication.Layout

/** One bounded offscreen Readium resource at a time; only integer counts survive.
 * No plugin reader, progress listener, network client or second publication owner.
 */
@OptIn(ExperimentalReadiumApi::class)
internal class EbookBookPagination(private val navigator: EpubNavigatorFragment) {
    private val publication = ReadiumReader.currentPublication
    private data class Key(val width: Int, val height: Int, val settings: List<Any?>)
    private data class Resource(val offset: Int, val count: Int, val columns: Int)
    private data class Book(val resources: Map<String, Resource>, val total: Int)
    private var key: Key? = null
    private var calculation: Deferred<Book>? = null
    var calculations = 0; private set
    var resourcesMeasured = 0; private set
    var activeResources = 0; private set

    suspend fun snapshot(): JSONObject? {
        val view = navigator.view ?: return null
        val publication = publication ?: return null
        if (!navigator.isResumed || navigator.settings.value.scroll ||
            publication.metadata.layout == Layout.FIXED || view.width <= 0 || view.height <= 0) return null
        val requested = layoutKey(view)
        if (key != requested || calculation?.isCancelled != false) {
            clear()
            key = requested
            calculation = navigator.lifecycleScope.async {
                calculations++
                measure(view as ViewGroup)
            }
        }
        val book = try { calculation!!.await() }
            catch (_: CancellationException) { return null }
            catch (error: Exception) {
                if (navigator.requireContext().applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0) {
                    android.util.Log.w("InkoraPagination", "Pagination calculation failed", error)
                }
                return null
            }
        if (key != requested || !navigator.isResumed) return null
        val locator = navigator.currentLocator.value
        val resource = book.resources[locator.href.removeFragment().toString()] ?: return null
        // The visible WebView can finish its font/layout work after preferences
        // are acknowledged. Wait only while that reflow is active, never poll an
        // idle reader or show numbers belonging to different geometry.
        val current = withTimeout(20000) {
            var data: JSONObject?
            while (true) {
                if (!navigator.isResumed || navigator.currentLocator.value != locator || key != requested) return@withTimeout null
                data = read(navigator)
                if (data != null && data.optBoolean("ready") && data.getInt("columns") == resource.columns &&
                    data.getInt("count") == resource.count) break
                delay(50)
            }
            data
        } ?: return null
        val columns = current.getInt("columns")
        val page = kotlin.math.round(current.getDouble("progression") * resource.count).toInt()
        val numbers = (0 until columns).map { resource.offset + (page + it).coerceAtMost(resource.count - 1) + 1 }
        return JSONObject().apply {
            put("pages", org.json.JSONArray(if (current.optBoolean("rtl")) numbers.reversed() else numbers))
            put("total", book.total)
        }
    }

    private suspend fun measure(root: ViewGroup): Book {
        val publication = publication ?: error("Missing EPUB publication")
        val model = (navigator.parentFragment as? EpubReaderFragment)?.vm as? EpubReaderViewModel
            ?: error("Missing EPUB configuration")
        val preferences = model.preferences ?: error("Missing EPUB preferences")
        val factory = model.navigatorFactory ?: error("Missing EPUB factory")
        val config = EpubNavigatorFragment.Configuration(
            shouldApplyInsetsPadding = false,
            servedAssets = listOf("flutter_assets/packages/flutter_readium/assets/.*") +
                model.fontFamilyDeclarations.flatMap { family -> family.faces.map { it.asset } },
        ).apply {
            model.fontFamilyDeclarations.forEach { family ->
                addFontFamilyDeclaration(FontFamily(family.name), family.fallbacks.map(::FontFamily)) {
                    family.faces.forEach { face ->
                        addFontFace {
                            addSource(face.asset)
                            setFontStyle(if (face.style == ReaderFontStyle.ITALIC) FontStyle.ITALIC else FontStyle.NORMAL)
                            FontWeight.entries.firstOrNull { it.value == face.weight }?.let(::setFontWeight)
                                ?: setFontWeight(face.weight..face.weight)
                        }
                    }
                }
            }
        }
        val resources = mutableMapOf<String, Resource>()
        var total = 0
        for (link in publication.readingOrder) {
            // Attach exactly one resource at the actual publication dimensions.
            // Translation keeps it outside the clipped visible reader viewport.
            val container = FrameLayout(root.context).apply {
                id = View.generateViewId()
                tag = COUNTER
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
                descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
                translationX = -2f * root.width
            }
            val fragment = factory.createFragmentFactory(
                initialLocator = publication.locatorFromLink(link),
                readingOrder = listOf(link),
                initialPreferences = preferences.toEpubPreferences(),
                configuration = config,
            ).instantiate(root.context.classLoader, EpubNavigatorFragment::class.java.name) as EpubNavigatorFragment
            fragment.arguments = Bundle().apply { putBoolean(COUNTER, true) }
            val manager = navigator.childFragmentManager
            root.addView(container, ViewGroup.LayoutParams(root.width, root.height))
            try {
                manager.beginTransaction().add(container.id, fragment).commitNow()
                activeResources++
                val (count, columns) = withTimeout(20000) {
                    var previous = -1
                    var columns = 1
                    while (true) {
                        delay(50)
                        val data = read(fragment) ?: continue
                        if (!data.optBoolean("ready")) continue
                        val count = data.getInt("count")
                        columns = data.getInt("columns")
                        if (count == previous) break
                        previous = count
                    }
                    previous to columns
                }
                resources[link.url().removeFragment().toString()] = Resource(total, count, columns)
                total += count
                resourcesMeasured++
            } finally {
                if (fragment.isAdded && !manager.isDestroyed) {
                    manager.beginTransaction().remove(fragment).commitNowAllowingStateLoss()
                }
                activeResources = 0
                root.removeView(container)
            }
        }
        return Book(resources, total)
    }

    fun stop() {
        if (calculation?.isCompleted != true) clear()
    }

    fun invalidate() {
        val view = navigator.view
        if (key != null && (view == null || key != layoutKey(view))) clear()
    }

    private fun layoutKey(view: View): Key {
        val settings = navigator.settings.value
        return Key(view.width, view.height, listOf(
            settings.fontFamily, settings.fontSize, settings.lineHeight,
            settings.pageMargins, settings.columnCount, settings.publisherStyles,
            settings.textAlign, settings.scroll, settings.readingProgression, settings.verticalText,
        ))
    }

    fun clear() {
        calculation?.cancel()
        calculation = null
        key = null
    }

    companion object {
        private const val COUNTER = "inkora-pagination-counter"
        fun isCounter(fragment: Fragment) = fragment.arguments?.getBoolean(COUNTER) == true
        fun isCounterView(view: View) = view.tag == COUNTER

        private suspend fun read(fragment: EpubNavigatorFragment): JSONObject? {
            val raw = fragment.evaluateJavascript("""(() => {
              const root = document.documentElement, style = getComputedStyle(root);
              if (!style.writingMode.startsWith('horizontal') || innerWidth <= 0) return null;
              const columns = parseInt(style.columnCount) === 2 ? 2 : 1;
              const width = Math.max(innerWidth,root.scrollWidth);
              const rtl = style.direction === 'rtl';
              const progression = rtl ? 1 - (Math.abs(scrollX) + innerWidth) / width : scrollX / width;
              return JSON.stringify({columns,rtl,progression:Math.max(0,progression),
                count:Math.max(columns,Math.round(width / innerWidth) * columns),
                ready:document.fonts.status === 'loaded' && Array.from(document.images).every(i => i.complete)});
            })()""")
            val decoded = JSONTokener(raw ?: "null").nextValue()
            return if (decoded is String) JSONObject(decoded) else decoded as? JSONObject
        }
    }
}
