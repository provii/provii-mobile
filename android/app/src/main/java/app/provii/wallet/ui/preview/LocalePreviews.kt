// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.preview

import androidx.compose.ui.tooling.preview.Preview

/**
 * Compose Preview annotation classes for multi-locale and multi-device rendering.
 * [LocalePreviews] covers five languages including two RTL scripts. [RTLPreviews]
 * targets four RTL locales specifically. [DeviceLocalePreviews] combines device
 * form factors with locale for responsive layout validation.
 */

/**
 * Multi-locale preview annotation for testing UI across languages.
 * Use this annotation on preview composables to see them in multiple locales.
 */
@Preview(name = "English", locale = "en", showBackground = true)
@Preview(name = "Arabic (RTL)", locale = "ar", showBackground = true)
@Preview(name = "Spanish", locale = "es", showBackground = true)
@Preview(name = "Chinese", locale = "zh", showBackground = true)
@Preview(name = "Hebrew (RTL)", locale = "he", showBackground = true)
annotation class LocalePreviews

/**
 * RTL-only preview annotation for testing right-to-left layouts.
 */
@Preview(name = "Arabic (RTL)", locale = "ar", showBackground = true)
@Preview(name = "Hebrew (RTL)", locale = "he", showBackground = true)
@Preview(name = "Persian (RTL)", locale = "fa", showBackground = true)
@Preview(name = "Urdu (RTL)", locale = "ur", showBackground = true)
annotation class RTLPreviews

/**
 * Device size previews combined with locale.
 */
@Preview(name = "Phone", device = "spec:width=411dp,height=891dp", locale = "en")
@Preview(name = "Phone RTL", device = "spec:width=411dp,height=891dp", locale = "ar")
@Preview(name = "Tablet", device = "spec:width=1280dp,height=800dp,dpi=240", locale = "en")
annotation class DeviceLocalePreviews
