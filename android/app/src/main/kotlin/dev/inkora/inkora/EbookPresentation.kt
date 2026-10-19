package dev.inkora.inkora

import android.os.Bundle
import android.content.pm.ApplicationInfo
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentManager
import androidx.lifecycle.lifecycleScope
import dk.nota.flutterreadium.ReadiumReader
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Job
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import org.readium.r2.navigator.epub.EpubNavigatorFragment
import org.readium.r2.navigator.input.InputListener
import org.readium.r2.navigator.input.KeyEvent
import org.readium.r2.navigator.input.TapEvent
import org.readium.r2.navigator.util.DirectionalNavigationAdapter

/** UI-only extension of the pinned navigator, using its public input/CSS APIs. */
class EbookPresentation(private val activity: FlutterFragmentActivity, messenger: BinaryMessenger) {
    private var animations = true
    private var separator = false
    private var imageEnhancement = 0
    private val navigators = mutableSetOf<EpubNavigatorFragment>()
    private val jobs = mutableMapOf<EpubNavigatorFragment, Job>()
    private val callbacks = object : FragmentManager.FragmentLifecycleCallbacks() {
        override fun onFragmentCreated(manager: FragmentManager, fragment: Fragment, state: Bundle?) {
            if (fragment !is EpubNavigatorFragment) return
            navigators.add(fragment)
            // Registered during fragment creation, before the plugin's default
            // navigation adapter. Selection and unhandled gestures still fall through.
            val animated = DirectionalNavigationAdapter(fragment, animatedTransition = true)
            val instant = DirectionalNavigationAdapter(fragment, animatedTransition = false)
            fragment.addInputListener(object : InputListener {
                override fun onTap(event: TapEvent) = (if (animations) animated else instant).onTap(event)
                override fun onKey(event: KeyEvent) = (if (animations) animated else instant).onKey(event)
            })
        }

        override fun onFragmentStarted(manager: FragmentManager, fragment: Fragment) {
            if (fragment !is EpubNavigatorFragment) return
            jobs.remove(fragment)?.cancel()
            jobs[fragment] = fragment.lifecycleScope.launch {
                fragment.currentLocator.map { it.href }.distinctUntilChanged().collect {
                    applyDivider(fragment)
                }
            }
        }

        override fun onFragmentStopped(manager: FragmentManager, fragment: Fragment) {
            if (fragment is EpubNavigatorFragment) jobs.remove(fragment)?.cancel()
        }

        override fun onFragmentDestroyed(manager: FragmentManager, fragment: Fragment) {
            if (fragment is EpubNavigatorFragment) jobs.remove(fragment)?.cancel()
            navigators.remove(fragment)
        }
    }

    init {
        activity.supportFragmentManager.registerFragmentLifecycleCallbacks(callbacks, true)
        MethodChannel(messenger, "inkora/ebook_presentation").setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *>
            when (call.method) {
                "configure" -> {
                    val animationValue = args?.get("animations") as? Boolean
                    val separatorValue = args?.get("separator") as? Boolean
                    val imageValue = (args?.get("imageEnhancement") as? Number)?.toInt() ?: 0
                    if (animationValue == null || separatorValue == null || imageValue !in 0..3) {
                        result.error("invalid_argument", "Expected presentation booleans.", null)
                    } else {
                        animations = animationValue
                        separator = separatorValue
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
                // Fixed scalar geometry for native debug verification; never
                // exposes document text or accepts an executable argument.
                "layout" -> {
                    if (activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) {
                        result.notImplemented()
                    } else activity.lifecycleScope.launch {
                        try {
                            result.success(ReadiumReader.epubEvaluateJavascript(
                                """(() => {
                                  const root = document.documentElement, style = getComputedStyle(root);
                                  const body = getComputedStyle(document.body);
                                  const middle = innerWidth / 2;
                                  const nodes = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
                                  let node, scanned = 0, crossingLines = 0;
                                  while (scanned++ < 300 && (node = nodes.nextNode())) {
                                    if (!node.textContent.trim()) continue;
                                    const range = document.createRange(); range.selectNodeContents(node);
                                    for (const rect of range.getClientRects()) {
                                      if (rect.width > 0 && rect.left < middle - 1 && rect.right > middle + 1) crossingLines++;
                                    }
                                  }
                                  return JSON.stringify({columns:style.columnCount,rule:style.columnRuleStyle,width:style.columnRuleWidth,paddingLeft:body.paddingLeft,paddingRight:body.paddingRight,crossingLines,viewportWidth:innerWidth,viewportHeight:innerHeight,enhancedImages:document.querySelectorAll('.inkora-enhanced-image').length});
                                })()"""
                            ))
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
            // CSS draws a rule only between actual columns. Single-column and
            // fixed-layout pages never get a spurious Flutter overlay line.
            val rule = if (separator) "1px solid black" else "none"
            val amount = doubleArrayOf(0.0, 0.2, 0.45, 0.7)[imageEnhancement]
            val kernel = "0 ${-amount} 0 ${-amount} ${1 + 4 * amount} ${-amount} 0 ${-amount} 0"
            navigator.evaluateJavascript(
                """(() => {
                  document.documentElement.style.setProperty('column-rule', '$rule', 'important');
                  // Keep Readium's zero-gap pagination geometry. Its body padding
                  // repeats inside each column; retain a gutter even when outer
                  // Flutter margins request zero native page margins.
                  if (!document.getElementById('inkora-spread-style')) {
                    const style = document.createElement('style');
                    style.id = 'inkora-spread-style';
                    style.textContent = ':root[data-inkora-spread="true"] body{padding-left:max(16px,calc(var(--RS__pageGutter,20px)*var(--USER__pageMargins,1)))!important;padding-right:max(16px,calc(var(--RS__pageGutter,20px)*var(--USER__pageMargins,1)))!important;overflow-wrap:anywhere!important}';
                    document.documentElement.appendChild(style);
                    const update = () => {
                      const root = document.documentElement;
                      const spread = Number(getComputedStyle(root).columnCount) >= 2;
                      const value = String(spread);
                      if (root.dataset.inkoraSpread !== value) root.dataset.inkoraSpread = value;
                    };
                    // Re-evaluate only on viewport/reflow changes, never on scroll.
                    new ResizeObserver(update).observe(document.documentElement);
                    new MutationObserver(update).observe(document.documentElement, {attributes:true,attributeFilter:['style']});
                    window.__inkoraUpdateSpread = update;
                  }
                  window.__inkoraUpdateSpread();
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
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) { /* A resource or navigator may be closing. */ }
    }

    fun close() {
        activity.supportFragmentManager.unregisterFragmentLifecycleCallbacks(callbacks)
        jobs.values.forEach { it.cancel() }
        jobs.clear()
        navigators.clear()
    }
}
