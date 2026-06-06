// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.utils

import android.content.Context
import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.core.text.layoutDirection
import timber.log.Timber
import java.util.Locale

/**
 * Utilities for RTL (Right-to-Left) layout support. Includes an enum of all RTL
 * languages supported by Provii Wallet, Compose helpers to force layout direction
 * in previews, and testing utilities for generating RTL configurations. The
 * [DirectionalIcons] object documents which icon categories should be mirrored
 * in RTL layouts and which should remain unchanged.
 */

/**
 * RTL languages supported by Provii Wallet
 */
enum class RtlLanguage(val code: String, val displayName: String) {
    ARABIC("ar", "العربية"),
    DARI("fa-AF", "دری"),
    FARSI("fa", "فارسی"),
    HEBREW("he", "עברית"),
    KURDISH("ku", "کوردی"),
    PASHTO("ps", "پښتو"),
    URDU("ur", "اردو"),
    ;

    companion object {
        /**
         * Check if a given locale is an RTL language
         */
        fun isRtlLocale(locale: Locale): Boolean {
            return values().any { it.code == locale.language || it.code == locale.toLanguageTag() }
        }

        /**
         * Get RTL language by locale code
         */
        fun fromLocale(locale: Locale): RtlLanguage? {
            return values().find { it.code == locale.language || it.code == locale.toLanguageTag() }
        }
    }
}

/**
 * Check if the current context is using RTL layout direction
 */
fun Context.isRtlLayout(): Boolean {
    return resources.configuration.layoutDirection == Configuration.SCREENLAYOUT_LAYOUTDIR_RTL ||
        resources.configuration.locale.layoutDirection == LayoutDirection.Rtl.ordinal
}

/**
 * Get the layout direction for a given locale
 */
fun getLayoutDirection(locale: Locale): LayoutDirection {
    return if (RtlLanguage.isRtlLocale(locale)) {
        LayoutDirection.Rtl
    } else {
        LayoutDirection.Ltr
    }
}

/**
 * Force RTL layout direction for testing purposes
 *
 * Usage:
 * ```
 * @Preview
 * @Composable
 * fun MyScreenPreview() {
 *     ForceRtlLayout {
 *         MyScreen()
 *     }
 * }
 * ```
 */
@Composable
fun ForceRtlLayout(content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        content()
    }
}

/**
 * Force LTR layout direction for testing purposes
 *
 * Usage:
 * ```
 * @Preview
 * @Composable
 * fun MyScreenPreview() {
 *     ForceLtrLayout {
 *         MyScreen()
 *     }
 * }
 * ```
 */
@Composable
fun ForceLtrLayout(content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        content()
    }
}

/**
 * Extension function to get the opposite layout direction
 */
fun LayoutDirection.opposite(): LayoutDirection {
    return when (this) {
        LayoutDirection.Ltr -> LayoutDirection.Rtl
        LayoutDirection.Rtl -> LayoutDirection.Ltr
    }
}

/**
 * Common directional icons that should be mirrored in RTL
 */
object DirectionalIcons {
    /**
     * Icons that indicate forward/next movement
     * Examples: ArrowForward, ChevronRight, KeyboardArrowRight, NavigateNext
     */
    const val FORWARD_INDICATORS = "forward"

    /**
     * Icons that indicate backward/previous movement
     * Examples: ArrowBack, ChevronLeft, KeyboardArrowLeft, NavigateBefore
     */
    const val BACKWARD_INDICATORS = "backward"

    /**
     * Icons that should NOT be mirrored
     * Examples: Settings, Search, Close, Add, Remove
     */
    const val NON_DIRECTIONAL = "non_directional"
}

/**
 * Debug utility to log RTL configuration.
 * Note: This function only logs in debug builds via Timber.
 */
fun Context.logRtlConfiguration() {
    val config = resources.configuration
    val locale = config.locale
    val isRtl = isRtlLayout()
    val rtlLanguage = RtlLanguage.fromLocale(locale)

    Timber.d(
        """
        RTL Configuration:
        Locale: ${locale.displayName}
        Language Code: ${locale.language}
        Is RTL: $isRtl
        RTL Language: ${rtlLanguage?.displayName ?: "Not an RTL language"}
        Layout Direction: ${if (isRtl) "RTL" else "LTR"}
        """.trimIndent(),
    )
}

/**
 * Testing utilities for RTL layouts
 */
object RtlTestingUtils {
    /**
     * Get a list of all supported RTL locales for testing
     */
    fun getAllRtlLocales(): List<Locale> {
        return RtlLanguage.entries.map { rtlLang ->
            when (rtlLang) {
                RtlLanguage.DARI ->
                    Locale.Builder()
                        .setLanguage("fa")
                        .setRegion("AF")
                        .build()
                else -> Locale.forLanguageTag(rtlLang.code)
            }
        }
    }

    /**
     * Create a configuration with RTL layout for testing
     */
    fun createRtlConfiguration(
        context: Context,
        locale: Locale,
    ): Configuration {
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        config.setLayoutDirection(locale)
        return config
    }

    /**
     * Recommended RTL test cases
     */
    val testCases =
        listOf(
            "Navigation arrows (back/forward buttons)",
            "Breadcrumb separators",
            "List item indicators",
            "Chevrons in expandable sections",
            "Drawer open/close icons",
            "Next/Previous pagination controls",
            "Text alignment (start/end instead of left/right)",
            "Padding and margins (start/end instead of left/right)",
            "Image placement in cards",
            "Icon positions in buttons",
        )
}
