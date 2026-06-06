// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.utils

import android.content.Context
import android.os.Build
import androidx.annotation.PluralsRes
import androidx.annotation.StringRes
import app.provii.wallet.R
import java.util.Locale

/**
 * Localisation utility functions for Provii Wallet. Provides Context extension
 * functions for string formatting, pluralisation, RTL detection, and locale
 * introspection. Pre-formatted helpers for percentages, age, step indicators,
 * and download progress are included to keep formatting consistent across screens.
 */
object LocalizationUtils {
    /**
     * Get a localized string by resource ID
     */
    fun Context.getLocalizedString(
        @StringRes resId: Int,
    ): String {
        return getString(resId)
    }

    /**
     * Get a formatted localized string
     */
    fun Context.getLocalizedString(
        @StringRes resId: Int,
        vararg formatArgs: Any,
    ): String {
        return getString(resId, *formatArgs)
    }

    /**
     * Get a pluralized string
     */
    fun Context.getQuantityString(
        @PluralsRes resId: Int,
        quantity: Int,
        vararg formatArgs: Any,
    ): String {
        return resources.getQuantityString(resId, quantity, *formatArgs)
    }

    /**
     * Get the current locale
     */
    fun Context.getCurrentLocale(): Locale {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            resources.configuration.locales[0]
        } else {
            @Suppress("DEPRECATION")
            resources.configuration.locale
        }
    }

    /**
     * Get the current language code (e.g., "en", "es", "fr")
     */
    fun Context.getCurrentLanguage(): String {
        return getCurrentLocale().language
    }

    /**
     * Get the current country code (e.g., "US", "AU", "GB")
     */
    fun Context.getCurrentCountry(): String {
        return getCurrentLocale().country
    }

    /**
     * Check if current locale is RTL (Right-to-Left)
     */
    fun Context.isRTL(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            resources.configuration.layoutDirection == android.view.View.LAYOUT_DIRECTION_RTL
        } else {
            false
        }
    }

    /**
     * Format a percentage string
     */
    fun Context.formatPercentage(value: Int): String {
        return getString(R.string.format_percentage, value)
    }

    /**
     * Format age in years
     */
    fun Context.formatAgeYears(years: Int): String {
        return getString(R.string.format_age_years, years)
    }

    /**
     * Format step indicator (e.g., "Step 1 of 2")
     */
    fun Context.formatStepIndicator(
        current: Int,
        total: Int,
    ): String {
        return getString(R.string.format_step_indicator, current, total)
    }

    /**
     * Format MB downloaded (e.g., "45.2 MB / 87.0 MB")
     */
    fun Context.formatMBDownloaded(
        downloaded: Float,
        total: Float,
    ): String {
        return getString(R.string.format_mb_downloaded, downloaded, total)
    }
}

/**
 * Extension function for easy string resource access
 */
fun Context.localizedString(
    @StringRes resId: Int,
    vararg formatArgs: Any,
): String {
    return if (formatArgs.isEmpty()) {
        getString(resId)
    } else {
        getString(resId, *formatArgs)
    }
}
