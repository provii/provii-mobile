// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// String and LocalizedString extensions for reading level aware text selection.
/// When the user's accessibility settings specify simplified reading, these helpers
/// return a simplified variant of the text, supporting WCAG 2.2 AAA criterion 3.1.5.

extension String {
    /// Returns simplified text if reading level is set to simplified, otherwise returns standard text
    /// - Parameter simplified: The simplified version of the text
    /// - Returns: Either simplified or standard text based on accessibility settings
    @MainActor
    func readingLevelAware(simplified: String) -> String {
        if AccessibilityManager.shared.settings.readingLevel == .simplified {
            return simplified
        }
        return self
    }
}

extension LocalizedString {
    /// Returns localised text with automatic reading level adjustment
    /// Looks for a "_simplified" variant of the key and uses it if reading level is simplified
    /// - Returns: Localised string appropriate for the current reading level
    @MainActor
    func localizedWithReadingLevel() -> String {
        let settings = AccessibilityManager.shared.settings

        if settings.readingLevel == .simplified {
            // Try to find simplified version with "_simplified" suffix
            let simplifiedKey = self.rawValue + "_simplified"
            let simplified = NSLocalizedString(simplifiedKey, comment: "")

            // If simplified version exists (i.e., not equal to key), use it
            if simplified != simplifiedKey {
                return simplified
            }
        }

        // Fall back to standard localization
        return self.localized
    }
}
