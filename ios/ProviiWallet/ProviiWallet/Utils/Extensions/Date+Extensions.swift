// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Date formatting and expiry helpers. Provides locale aware absolute and relative
/// date formatting, an expiry check, and a human readable time until expiry string.

extension Date {
    func formatted(as format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }

    /// Returns a localised date string using the system's locale settings
    func localizedFormatted(dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .none) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }

    var isExpired: Bool {
        return self < Date()
    }

    /// Returns a localised string describing the time until expiry
    var timeUntilExpiry: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale.current

        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(), to: self)

        // Use RelativeDateTimeFormatter for proper localization
        if self <= Date() {
            return NSLocalizedString("time_expired", value: "Expired", comment: "Time until expiry - expired")
        }

        if let days = components.day, days > 0 {
            return String(format: NSLocalizedString("time_in_days", value: "in %d days", comment: "Time until expiry - days"), days)
        } else if let hours = components.hour, hours > 0 {
            return String(format: NSLocalizedString("time_in_hours", value: "in %d hours", comment: "Time until expiry - hours"), hours)
        } else if let minutes = components.minute, minutes > 0 {
            return String(format: NSLocalizedString("time_in_minutes", value: "in %d minutes", comment: "Time until expiry - minutes"), minutes)
        } else {
            return NSLocalizedString("time_expired", value: "Expired", comment: "Time until expiry - expired")
        }
    }

    /// Returns a relative time string using the system's locale (e.g., "5 minutes ago", "in 2 days")
    var localizedRelativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale.current
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
