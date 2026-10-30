package dev.inkora.inkora

import android.os.Bundle
import android.view.View
import android.content.pm.ApplicationInfo
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentManager
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.Lifecycle
import dk.nota.flutterreadium.ReadiumReader
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Job
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import org.readium.r2.navigator.epub.EpubNavigatorFragment
import org.readium.r2.navigator.input.InputListener
import org.readium.r2.navigator.input.KeyEvent
import org.readium.r2.navigator.input.TapEvent
import org.readium.r2.navigator.util.DirectionalNavigationAdapter
import org.readium.r2.navigator.preferences.ColumnCount
import org.json.JSONObject
import org.json.JSONTokener

/** UI-only extension of the pinned navigator, using its public input/CSS APIs. */
class EbookPresentation(private val activity: FlutterFragmentActivity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "inkora/ebook_presentation")
    private var animations = true
    private var separator = false
    private var paperTexture = false
    private var dividerColor = 0xff252320.toInt()
    private var tapToTurnPages = false
    private var pageNumbers = true
    private var imageEnhancement = 0
    private val navigators = mutableSetOf<EpubNavigatorFragment>()
    private val jobs = mutableMapOf<EpubNavigatorFragment, Job>()
    private val dividers = mutableMapOf<EpubNavigatorFragment, EbookSpreadDivider>()
    private val pagination = mutableMapOf<EpubNavigatorFragment, EbookBookPagination>()

    private val callbacks = object : FragmentManager.FragmentLifecycleCallbacks() {
        override fun onFragmentCreated(manager: FragmentManager, fragment: Fragment, state: Bundle?) {
            if (fragment !is EpubNavigatorFragment || EbookBookPagination.isCounter(fragment)) return
            navigators.add(fragment)
            pagination[fragment] = EbookBookPagination(fragment)
            // Registered during fragment creation, before the plugin's default
            // navigation adapter. Selection and unhandled gestures still fall through.
            val animated = DirectionalNavigationAdapter(fragment, animatedTransition = true)
            val instant = DirectionalNavigationAdapter(fragment, animatedTransition = false)
            fragment.addInputListener(object : InputListener {
                // Consume unhandled taps before the plugin's default edge-tap
                // adapter. Native drags, text selection and keys stay intact;
                // Flutter's existing pointer listener owns control toggling.
                override fun onTap(event: TapEvent) =
                    !tapToTurnPages || (if (animations) animated else instant).onTap(event)
                override fun onKey(event: KeyEvent) = (if (animations) animated else instant).onKey(event)
            })
        }

        override fun onFragmentViewCreated(manager: FragmentManager, fragment: Fragment, view: View, state: Bundle?) {
            if (fragment is EpubNavigatorFragment && !EbookBookPagination.isCounter(fragment)) {
                dividers.remove(fragment)?.close()
                dividers[fragment] = EbookSpreadDivider(view) {
                    if (fragment.isAdded && fragment.isResumed) {
                        fragment.lifecycleScope.launch {
                            refreshDivider(fragment)
                            channel.invokeMethod("paginationChanged", null)
                        }
                        pagination[fragment]?.invalidate()
                    }
                }
            }
        }

        override fun onFragmentViewDestroyed(manager: FragmentManager, fragment: Fragment) {
            if (fragment is EpubNavigatorFragment) dividers.remove(fragment)?.close()
        }

        override fun onFragmentStarted(manager: FragmentManager, fragment: Fragment) {
            if (fragment !is EpubNavigatorFragment || EbookBookPagination.isCounter(fragment)) return
            jobs.remove(fragment)?.cancel()
            jobs[fragment] = fragment.lifecycleScope.launch {
                combine(
                    fragment.currentLocator.map { it.href }.distinctUntilChanged(),
                    fragment.settings,
                ) { href, layout -> href to layout }.collect {
                    pagination[fragment]?.invalidate()
                    applyDivider(fragment)
                }
            }
        }

        override fun onFragmentStopped(manager: FragmentManager, fragment: Fragment) {
            if (fragment is EpubNavigatorFragment) {
                jobs.remove(fragment)?.cancel()
                dividers[fragment]?.show(false)
                pagination[fragment]?.stop()
            }
        }

        override fun onFragmentDestroyed(manager: FragmentManager, fragment: Fragment) {
            if (fragment is EpubNavigatorFragment) jobs.remove(fragment)?.cancel()
            if (fragment is EpubNavigatorFragment) dividers.remove(fragment)?.close()
            if (fragment is EpubNavigatorFragment) pagination.remove(fragment)?.clear()
            navigators.remove(fragment)
        }
    }

    init {
        activity.supportFragmentManager.registerFragmentLifecycleCallbacks(callbacks, true)
        channel.setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *>
            when (call.method) {
                "paperTile" -> activity.lifecycleScope.launch {
                    try { result.success(EbookPaperTexture.bytes(activity)) }
                    catch (error: CancellationException) { throw error }
                    catch (error: Exception) {
                        if (activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
                            android.util.Log.w("InkoraPaper", "Paper texture preparation failed", error)
                        }
                        result.error("paper_texture", "Unable to prepare paper texture.", null)
                    }
                }
                "trimMemory" -> {
                    EbookPaperTexture.trimMemory()
                    pagination.values.forEach { it.clear() }
                    result.success(null)
                }
                "configure" -> {
                    val animationValue = args?.get("animations") as? Boolean
                    val separatorValue = args?.get("separator") as? Boolean
                    val tapValue = args?.get("tapToTurnPages") as? Boolean ?: false
                    val imageValue = (args?.get("imageEnhancement") as? Number)?.toInt() ?: 0
                    if (animationValue == null || separatorValue == null || imageValue !in 0..3) {
                        result.error("invalid_argument", "Expected presentation booleans.", null)
                    } else {
                        animations = animationValue
                        separator = separatorValue
                        paperTexture = args?.get("paperTexture") as? Boolean ?: false
                        pageNumbers = args?.get("pageNumbers") as? Boolean ?: true
                        if (!pageNumbers) pagination.values.forEach { it.clear() }
                        dividerColor = (args?.get("dividerColor") as? Number)?.toInt() ?: 0xff252320.toInt()
                        tapToTurnPages = tapValue
                        imageEnhancement = imageValue
                        activity.lifecycleScope.launch {
                            navigators.toList().forEach { applyDivider(it) }
                            result.success(true)
                        }
                    }
                }
                "turn" -> {
                    val forward = args?.get("forward") as? Boolean
                    val animate = args?.get("animated") as? Boolean
                    if (forward == null || animate == null) {
                        result.error("invalid_argument", "Expected navigation booleans.", null)
                    } else activity.lifecycleScope.launch {
                        try {
                            if (forward) ReadiumReader.epubGoForward(animate && animations)
                            else ReadiumReader.epubGoBackward(animate && animations)
                            result.success(true)
                        } catch (_: Exception) {
                            result.error("ebook_navigation", "Unable to turn the page.", null)
                        }
                    }
                }
                "pagination" -> activity.lifecycleScope.launch {
                    val navigator = navigators.firstOrNull { it.isResumed }
                    try { result.success(if (pageNumbers) pagination[navigator]?.snapshot()?.toString() else null) }
                    catch (_: CancellationException) { result.success(null) }
                    catch (_: Exception) { result.success(null) }
                }
                // Fixed scalar geometry for native debug verification; never
                // exposes document text or accepts an executable argument.
                "layout" -> {
                    if (activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) {
                        result.notImplemented()
                    } else activity.lifecycleScope.launch {
                        try {
                            val raw = ReadiumReader.epubEvaluateJavascript(
                                """(() => {
                                  const root = document.documentElement, style = getComputedStyle(root);
                                  const body = getComputedStyle(document.body);
                                  const middle = innerWidth / 2;
                                  const nodes = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
                                  let node, scanned = 0, crossingLines = 0, firstText = null;
                                  while (scanned++ < 300 && (node = nodes.nextNode())) {
                                    if (!node.textContent.trim()) continue;
                                    const range = document.createRange(); range.selectNodeContents(node);
                                    for (const rect of range.getClientRects()) {
                                      if (!firstText && rect.width > 0 && rect.height > 0) firstText = [rect.x,rect.y,rect.width,rect.height];
                                      if (rect.width > 0 && rect.left < middle - 1 && rect.right > middle + 1) crossingLines++;
                                    }
                                  }
                                  return JSON.stringify({backgroundColor:style.backgroundColor,textColor:body.color,paperBackgroundSize:style.backgroundSize,paperTexture:!!document.getElementById('inkora-paper-style'),paperImage:getComputedStyle(root).backgroundImage.includes('data:image/png'),devicePixelRatio,visualScale:visualViewport?.scale ?? 1,rootTransform:style.transform,bodyTransform:body.transform,textRendering:body.textRendering,rootZoom:style.zoom,firstText,fontsLoaded:document.fonts.status === 'loaded',fontFamily:body.fontFamily,fontSize:parseFloat(body.fontSize),loadedFontFamilies:Array.from(document.fonts).filter(face => face.status === 'loaded').slice(0,32).map(face => face.family),lateLayoutStyle:!!document.getElementById('inkora-spread-style'),columns:style.columnCount,rule:style.columnRuleStyle,width:style.columnRuleWidth,paddingLeft:body.paddingLeft,paddingRight:body.paddingRight,crossingLines,viewportWidth:innerWidth,viewportHeight:innerHeight,enhancedImages:document.querySelectorAll('.inkora-enhanced-image').length});
                                })()"""
                            )
                            val decoded = JSONTokener(raw ?: "null").nextValue()
                            val probe = if (decoded is String) JSONObject(decoded) else decoded as JSONObject
                            val counter = pagination.entries.firstOrNull { it.key.isResumed }?.value
                            probe.put("paginationCalculations", counter?.calculations ?: 0)
                            probe.put("paginationResourcesMeasured", counter?.resourcesMeasured ?: 0)
                            probe.put("paginationActiveResources", counter?.activeResources ?: 0)
                            val divider = dividers.entries.firstOrNull { it.key.isResumed }?.value
                            val visible = divider != null && divider.alpha > 0 && divider.segments.isNotEmpty()
                            val scale = if (divider == null || divider.view.width == 0) 0.0
                                else probe.optDouble("viewportWidth") / divider.view.width
                            probe.put("dividerCount", if (visible) divider!!.segments.size else 0)
                            probe.put("dividerAlpha", divider?.alpha ?: 0)
                            probe.put("dividerGradientBuilds", divider?.gradientBuilds ?: 0)
                            probe.put("paperTileWidth", EbookPaperTexture.tileWidth)
                            probe.put("paperTileHeight", EbookPaperTexture.tileHeight)
                            probe.put("paperEncodedLength", EbookPaperTexture.encodedLength)
                            probe.put("paperDecodeCount", EbookPaperTexture.decodeCount)
                            probe.put("dividerColor", divider?.color?.toLong()?.and(0xffffffffL) ?: 0)
                            probe.put("dividerSegments", org.json.JSONArray(divider?.segments?.map { listOf(it.left * scale, it.top * scale, it.width() * scale, it.height() * scale) } ?: emptyList<List<Double>>()))
                            probe.put("dividerVisible", visible)
                            probe.put("dividerLeft", (divider?.segments?.firstOrNull()?.left ?: 0) * scale)
                            probe.put("dividerWidth", (divider?.segments?.firstOrNull()?.width() ?: 0) * scale)
                            probe.put("dividerHeight", (divider?.segments?.firstOrNull()?.height() ?: 0) * scale)
                            result.success(probe.toString())
                        } catch (_: Exception) { result.success(null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private suspend fun applyDivider(navigator: EpubNavigatorFragment) {
        if (!navigator.isAdded) return
        try {
            // Remove column rules at clipped pagination edges. The only line is
            // native page-attached geometry outside HTML pagination.
            val selectedPaper = paperTexture
            val paper = if (selectedPaper) EbookPaperTexture.url(activity) else null
            if (!navigator.isAdded || selectedPaper != paperTexture) return
            val paperCSS = if (paper == null) "" else "html{background-image:url(\"$paper\")!important;background-repeat:repeat!important;background-size:calc(${EbookPaperTexture.tileWidth}px / var(--inkora-paper-dpr, 1)) calc(${EbookPaperTexture.tileHeight}px / var(--inkora-paper-dpr, 1))!important}body{background-color:transparent!important}"
            val amount = doubleArrayOf(0.0, 0.2, 0.45, 0.7)[imageEnhancement]
            val kernel = "0 ${-amount} 0 ${-amount} ${1 + 4 * amount} ${-amount} 0 ${-amount} 0"
            navigator.evaluateJavascript(
                """(() => {
                  const root = document.documentElement;
                  root.style.setProperty('--inkora-paper-dpr', String(devicePixelRatio));
                  document.getElementById('inkora-paper-style')?.remove();
                  if (${paper != null}) {
                    const paper = document.createElement('style');
                    paper.id = 'inkora-paper-style';
                    paper.textContent = ${JSONObject.quote(paperCSS)};
                    document.head.appendChild(paper);
                  }
                  root.style.setProperty('column-rule', 'none', 'important');
                  // Text geometry belongs to initial Readium preferences.
                  // Never add body padding after the resource becomes visible.
                  window.__inkoraImageObserver?.disconnect();
                  document.querySelectorAll('.inkora-enhanced-image').forEach(i => i.classList.remove('inkora-enhanced-image'));
                  document.getElementById('inkora-enhancement-style')?.remove();
                  document.getElementById('inkora-enhancement-svg')?.remove();
                  if ($amount > 0 && document.querySelector('img,svg image')) {
                    const ns = 'http://www.w3.org/2000/svg';
                    const svg = document.createElementNS(ns,'svg');
                    svg.id = 'inkora-enhancement-svg';
                    svg.setAttribute('width','0'); svg.setAttribute('height','0');
                    svg.style.position = 'absolute'; svg.style.pointerEvents = 'none';
                    const filter = document.createElementNS(ns,'filter');
                    filter.id = 'inkora-image-enhancement';
                    filter.setAttribute('color-interpolation-filters','sRGB');
                    const convolution = document.createElementNS(ns,'feConvolveMatrix');
                    convolution.setAttribute('order','3');
                    convolution.setAttribute('kernelMatrix','$kernel');
                    convolution.setAttribute('divisor','1');
                    convolution.setAttribute('edgeMode','duplicate');
                    convolution.setAttribute('preserveAlpha','true');
                    filter.appendChild(convolution); svg.appendChild(filter);
                    document.documentElement.appendChild(svg);
                    const style = document.createElement('style');
                    style.id = 'inkora-enhancement-style';
                    style.textContent = '.inkora-enhanced-image{filter:url(#inkora-image-enhancement) !important}';
                    document.documentElement.appendChild(style);
                    // Limit extra native filter surfaces to 2 Mi pixels/image.
                    // ResizeObserver reacts to layout/reflow, never scroll pixels.
                    const update = image => {
                      const r = image.getBoundingClientRect(), d = window.devicePixelRatio || 1;
                      image.classList.toggle('inkora-enhanced-image',r.width > 0 && r.height > 0 && r.width*d <= 4096 && r.height*d <= 4096 && r.width*r.height*d*d <= 2097152);
                    };
                    const observer = new ResizeObserver(entries => entries.forEach(e => update(e.target)));
                    document.querySelectorAll('img,svg image').forEach(image => {update(image);observer.observe(image)});
                    window.__inkoraImageObserver = observer;
                  }
                  return true;
                })()"""
            )
            refreshDivider(navigator)
            if (navigator.isResumed) channel.invokeMethod("paginationChanged", null)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) { /* A resource or navigator may be closing. */ }
    }

    private suspend fun refreshDivider(navigator: EpubNavigatorFragment) {
        val divider = dividers[navigator] ?: return
        divider.color = dividerColor
        if (!navigator.isAdded || !separator || navigator.settings.value.scroll ||
            navigator.settings.value.columnCount == ColumnCount.ONE) {
            divider.show(false)
            return
        }
        try {
            val columns = navigator.evaluateJavascript("getComputedStyle(document.documentElement).columnCount")
                ?.trim('"')?.toIntOrNull() ?: 1
            if (dividers[navigator] === divider) {
                divider.show(columns > 1 && separator && navigator.isAdded &&
                    navigator.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED) &&
                    !navigator.settings.value.scroll && navigator.settings.value.columnCount != ColumnCount.ONE)
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) { divider.show(false) }
    }

    fun close() {
        activity.supportFragmentManager.unregisterFragmentLifecycleCallbacks(callbacks)
        jobs.values.forEach { it.cancel() }
        jobs.clear()
        pagination.values.forEach { it.clear() }
        pagination.clear()
        navigators.clear()
        dividers.values.forEach { it.close() }
        dividers.clear()
        EbookPaperTexture.trimMemory()
    }
}
