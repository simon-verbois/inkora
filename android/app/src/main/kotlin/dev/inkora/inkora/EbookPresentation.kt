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
                    if (animationValue == null || separatorValue == null) {
                        result.error("invalid_argument", "Expected presentation booleans.", null)
                    } else {
                        animations = animationValue
                        separator = separatorValue
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
                                "JSON.stringify({columns:getComputedStyle(document.documentElement).columnCount,rule:getComputedStyle(document.documentElement).columnRuleStyle,width:getComputedStyle(document.documentElement).columnRuleWidth})"
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
            navigator.evaluateJavascript(
                "document.documentElement.style.setProperty('column-rule', '$rule', 'important');"
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
