// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import Foundation

/// Application wide constants including Keychain service identifiers and UserDefaults
/// keys for non sensitive preferences. Sensitive material must never be stored in
/// UserDefaults; use the Keychain constants defined here instead. API endpoint URLs
/// are resolved at runtime by EnvironmentManager (per environment from api-endpoints.json).
struct AppConstants {
    static let appScheme = "provii"
    static let supportEmail = "support@provii.app"
    static let privacyPolicyURL = "https://provii.app/privacy"
    static let termsOfServiceURL = "https://provii.app/terms"

    struct Keychain {
        static let serviceIdentifier = "app.provii.wallet"
        static let credentialKey = "stored_credentials"
        static let sessionKey = "active_session"
    }

    struct UserDefaults {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let enableBiometrics = "enableBiometrics"
        static let enableNotifications = "enableNotifications"
    }
}
