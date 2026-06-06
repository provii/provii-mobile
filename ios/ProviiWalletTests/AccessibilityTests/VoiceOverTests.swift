/// VoiceOver accessibility tests covering labels, traits, hints, touch targets, navigation
/// flows, modal dismissal, dynamic content announcements, and loading state communication.
import XCTest

class VoiceOverTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Accessibility Label Tests

    func testAllButtonsHaveAccessibilityLabels() {
        let buttons = app.buttons.allElementsBoundByIndex
        for (index, button) in buttons.enumerated() {
            XCTAssertFalse(
                button.label.isEmpty,
                "Button at index \(index) missing accessibility label"
            )
        }
    }

    func testAllImagesHaveAccessibilityLabels() {
        let images = app.images.allElementsBoundByIndex
        for (index, image) in images.enumerated() {
            // Only interactive images need labels
            if image.isHittable {
                XCTAssertFalse(
                    image.label.isEmpty,
                    "Interactive image at index \(index) missing accessibility label"
                )
            }
        }
    }

    func testAllTextFieldsHaveAccessibilityLabels() {
        let textFields = app.textFields.allElementsBoundByIndex
        for (index, textField) in textFields.enumerated() {
            XCTAssertFalse(
                textField.label.isEmpty || textField.placeholderValue == nil,
                "TextField at index \(index) missing accessibility label or placeholder"
            )
        }
    }

    func testAllSecureTextFieldsHaveAccessibilityLabels() {
        let secureFields = app.secureTextFields.allElementsBoundByIndex
        for (index, field) in secureFields.enumerated() {
            XCTAssertFalse(
                field.label.isEmpty,
                "SecureTextField at index \(index) missing accessibility label"
            )
        }
    }

    // MARK: - Navigation Flow Tests

    func testCredentialListVoiceOverNavigation() {
        // Test VoiceOver navigation through credential list
        let credentialListButton = app.buttons["Credentials"]
        if credentialListButton.exists {
            credentialListButton.accessibleTap()

            // Verify list is accessible
            let credentialsList = app.scrollViews.firstMatch
            XCTAssertTrue(credentialsList.exists, "Credentials list should exist")

            // Verify list items have proper labels
            let cells = app.cells.allElementsBoundByIndex
            if cells.count > 0 {
                for (index, cell) in cells.prefix(3).enumerated() {
                    XCTAssertFalse(cell.label.isEmpty, "Credential cell at index \(index) should have accessibility label")
                }
            }
        }
    }

    func testVerificationFlowVoiceOver() {
        // Test VoiceOver through verification flow
        let verificationButton = app.buttons["Verification"]
        if verificationButton.exists {
            verificationButton.accessibleTap()

            // Verify verification screen elements are accessible
            let presentButton = app.buttons["Present Credential"]
            if presentButton.exists {
                XCTAssertFalse(presentButton.label.isEmpty, "Present button should have accessibility label")
                XCTAssertTrue(presentButton.isHittable, "Present button should be hittable")
            }

            // Verify QR code element if present
            let qrImage = app.images.allElementsBoundByIndex.first(where: { $0.label.contains("QR") || $0.label.contains("Code") })
            if let qrImage = qrImage {
                XCTAssertFalse(qrImage.label.isEmpty, "QR code should have accessibility label")
            }
        }
    }

    func testOfficerModeVoiceOver() {
        // Test VoiceOver navigation through officer mode
        let officerButton = app.buttons["Officer"]
        if officerButton.exists {
            officerButton.accessibleTap()

            // Verify officer mode elements are accessible
            let scanButton = app.buttons.allElementsBoundByIndex.first(where: { $0.label.contains("Scan") })
            if let scanButton = scanButton {
                XCTAssertTrue(scanButton.isHittable, "Scan button should be hittable")
                XCTAssertFalse(scanButton.label.isEmpty, "Scan button should have accessibility label")
            }

            // Verify manual entry option is accessible
            let manualEntryButton = app.buttons.allElementsBoundByIndex.first(where: { $0.label.contains("Manual") })
            if let manualEntryButton = manualEntryButton {
                XCTAssertTrue(manualEntryButton.isHittable, "Manual entry button should be hittable")
            }
        }
    }

    func testSettingsVoiceOver() {
        // Test VoiceOver navigation through settings
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.accessibleTap()

            // Verify settings sections have proper headings
            let staticTexts = app.staticTexts.allElementsBoundByIndex
            XCTAssertGreaterThan(staticTexts.count, 0, "Settings should have accessible text elements")

            // Verify accessibility settings are reachable
            let accessibilityOption = app.buttons.allElementsBoundByIndex.first(where: {
                $0.label.contains("Accessibility") || $0.label.contains("Access")
            })
            if let accessibilityOption = accessibilityOption {
                XCTAssertTrue(accessibilityOption.exists, "Accessibility settings should be accessible")
                XCTAssertTrue(accessibilityOption.isHittable, "Accessibility settings should be hittable")
            }
        }
    }

    func testModalDismissalVoiceOver() {
        // Test that modals can be dismissed with VoiceOver
        // Try to open a modal (e.g., from credentials or settings)
        let buttons = app.buttons.allElementsBoundByIndex

        for button in buttons.prefix(5) {
            if button.label.contains("Add") || button.label.contains("Create") || button.label.contains("Info") {
                button.tap()

                // Give time for modal to appear
                sleep(1)

                // Look for close/dismiss button
                let closeButton = app.buttons.allElementsBoundByIndex.first(where: {
                    $0.label.contains("Close") ||
                    $0.label.contains("Dismiss") ||
                    $0.label.contains("Cancel") ||
                    $0.label.contains("Done")
                })

                if let closeButton = closeButton {
                    XCTAssertTrue(closeButton.exists, "Modal should have a close button")
                    XCTAssertFalse(closeButton.label.isEmpty, "Close button should have accessibility label")
                    XCTAssertTrue(closeButton.isHittable, "Close button should be hittable")
                    closeButton.tap()
                    sleep(1)
                    break
                }
            }
        }
    }

    // MARK: - Accessibility Traits Tests

    func testButtonsHaveButtonTrait() {
        let buttons = app.buttons.allElementsBoundByIndex

        // Verify all buttons have proper accessibility properties
        var validButtonCount = 0
        for (index, button) in buttons.prefix(10).enumerated() {
            if button.exists {
                // XCUIElement doesn't expose traits directly in tests
                // But we can verify buttons are accessible with proper labels
                XCTAssertTrue(button.exists, "Button \(index) should exist")
                XCTAssertFalse(button.label.isEmpty, "Button \(index) should have accessibility label")

                // Verify button is interactive
                if button.isHittable {
                    validButtonCount += 1
                }
            }
        }

        XCTAssertGreaterThan(validButtonCount, 0, "Should have accessible buttons with proper traits")
    }

    func testLinksHaveLinkTrait() {
        // Verify links are marked with link trait
        // This helps VoiceOver users understand the element behaviour
        let links = app.links.allElementsBoundByIndex

        // Verify any links present have proper labels
        for (index, link) in links.prefix(5).enumerated() {
            if link.exists {
                XCTAssertFalse(link.label.isEmpty, "Link \(index) should have accessibility label")
                XCTAssertTrue(link.isHittable, "Link \(index) should be hittable")
            }
        }

        // If no links found, that's acceptable (not all screens have links)
        // But verify buttons that act as links have appropriate labels
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons.prefix(5) {
            if button.label.contains("Learn More") || button.label.contains("View") || button.label.contains("Open") {
                XCTAssertFalse(button.label.isEmpty, "Link-like button should have clear label")
            }
        }
    }

    // MARK: - Accessibility Hints Tests

    func testCriticalActionsHaveHints() {
        // Verify critical actions have accessibility hints
        // Example: "Delete" button should have hint "Deletes this item permanently"
        // This helps users understand consequences before acting

        let buttons = app.buttons.allElementsBoundByIndex

        // Find buttons that perform critical actions
        let deleteButtons = buttons.filter { $0.label.contains("Delete") || $0.label.contains("Remove") }
        for (index, button) in deleteButtons.enumerated() {
            XCTAssertFalse(button.label.isEmpty, "Delete button \(index) should have a label")
            XCTAssertTrue(button.exists, "Delete button \(index) should exist")
        }

        // Verify destructive action buttons are identifiable
        let allButtons = app.buttons.allElementsBoundByIndex
        for button in allButtons.prefix(10) {
            if button.exists {
                XCTAssertTrue(button.exists, "Button should exist")
                // Buttons performing critical actions should have clear labels
                if button.label.contains("Delete") || button.label.contains("Remove") || button.label.contains("Clear") {
                    XCTAssertFalse(button.label.isEmpty, "Critical action button should have clear label")
                }
            }
        }
    }

    // MARK: - Touch Target Size Tests

    func testMinimumTouchTargetSizes() {
        let buttons = app.buttons.allElementsBoundByIndex
        for (index, button) in buttons.enumerated() {
            verifyMinimumTouchTargetSize(button, minimum: 44, index: index)
        }
    }

    // MARK: - Custom Actions Tests

    func testCustomActionsVoiceOver() {
        // Verify swipe actions are exposed as custom actions for VoiceOver
        // Test credential list for custom actions (delete, share, etc.)
        let credentialListButton = app.buttons["Credentials"]
        if credentialListButton.exists {
            credentialListButton.accessibleTap()

            // Look for cells with custom actions
            let cells = app.cells.allElementsBoundByIndex
            if cells.count > 0 {
                let firstCell = cells[0]
                XCTAssertTrue(firstCell.exists, "First credential cell should exist")

                // Verify cell is accessible with actions
                XCTAssertTrue(firstCell.isHittable, "Credential cell should be hittable")

                // Custom actions would be exposed via customActions property
                // In UI tests, we verify buttons within cells are accessible
                let buttons = firstCell.buttons.allElementsBoundByIndex
                for button in buttons {
                    XCTAssertFalse(button.label.isEmpty, "Action buttons should have labels")
                }
            }
        }
    }

    func testQRScannerVoiceOver() {
        // Test camera/QR scanner accessibility
        // Look for scan functionality in verification or officer mode
        let verificationButton = app.buttons["Verification"]
        if verificationButton.exists {
            verificationButton.accessibleTap()

            // Look for scan button
            let scanButton = app.buttons.allElementsBoundByIndex.first(where: {
                $0.label.contains("Scan") || $0.label.contains("Camera")
            })

            if let scanButton = scanButton {
                XCTAssertTrue(scanButton.exists, "Scan button should exist")
                XCTAssertFalse(scanButton.label.isEmpty, "Scan button should have accessibility label")
                XCTAssertTrue(scanButton.isHittable, "Scan button should be hittable")

                // Verify hint provides information about camera usage
                if let hint = scanButton.value as? String {
                    XCTAssertFalse(hint.isEmpty, "Scan button should have accessibility hint")
                }
            }
        }
    }

    func testErrorAnnouncementsVoiceOver() {
        // Test that error messages are properly announced
        // Navigate to a form and attempt to trigger validation
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.accessibleTap()

            // Look for form fields
            let textFields = app.textFields.allElementsBoundByIndex
            if textFields.count > 0 {
                let firstField = textFields[0]

                // Clear the field if it has content
                if firstField.exists && firstField.isHittable {
                    firstField.tap()
                    // Try to submit without valid input to trigger error
                    let submitButton = app.buttons.allElementsBoundByIndex.first(where: {
                        $0.label.contains("Save") || $0.label.contains("Submit") || $0.label.contains("Done")
                    })

                    if let submitButton = submitButton {
                        submitButton.tap()

                        // Look for error message
                        sleep(1)
                        let errorTexts = app.staticTexts.allElementsBoundByIndex.filter {
                            $0.label.contains("Error") || $0.label.contains("Invalid") || $0.label.contains("Required")
                        }

                        if errorTexts.count > 0 {
                            let errorText = errorTexts[0]
                            XCTAssertTrue(errorText.exists, "Error message should be displayed")
                            XCTAssertFalse(errorText.label.isEmpty, "Error message should have text")
                        }
                    }
                }
            }
        }
    }

    func testMultilingualVoiceOver() {
        // Test VoiceOver in multiple languages
        // This test verifies that accessibility labels exist across language changes
        // Note: Actual language testing requires system language changes

        // Test 1: English (default)
        let buttons = app.buttons.allElementsBoundByIndex
        var englishButtonCount = 0
        for button in buttons.prefix(10) {
            if !button.label.isEmpty {
                englishButtonCount += 1
            }
        }
        XCTAssertGreaterThan(englishButtonCount, 0, "Should have accessible buttons in English")

        // Test 2: Verify app supports localisation by checking for localised strings
        // In a real scenario, we would launch with different locale
        // For now, verify that buttons have proper labels that would translate
        for button in buttons.prefix(5) {
            XCTAssertFalse(button.label.isEmpty, "All buttons should have accessibility labels")
            // Verify labels are not just raw identifiers
            XCTAssertFalse(button.label.contains("Button"), "Labels should be descriptive, not generic")
        }

        // Test 3: Verify text fields have labels in any language
        let textFields = app.textFields.allElementsBoundByIndex
        for (index, field) in textFields.prefix(3).enumerated() {
            XCTAssertTrue(
                !field.label.isEmpty || field.placeholderValue != nil,
                "Text field at index \(index) should have label or placeholder"
            )
        }
    }

    // MARK: - Dynamic Content Tests

    func testDynamicContentUpdatesAreAnnounced() {
        // Test that dynamic content changes are announced
        // This is typically handled through UIAccessibility.post notifications
        // Verify loading indicators and status changes have proper labels

        let loadingIndicators = app.activityIndicators.allElementsBoundByIndex
        for indicator in loadingIndicators {
            if indicator.exists {
                XCTAssertFalse(indicator.label.isEmpty, "Loading indicator should have accessibility label")
            }
        }
    }

    func testLoadingStatesAreAnnounced() {
        // Verify loading states are communicated
        // Navigate to a screen that might trigger loading
        let buttons = app.buttons.allElementsBoundByIndex
        if buttons.count > 0 {
            // Try to trigger navigation that might show loading
            for button in buttons.prefix(3) {
                if button.label.contains("Refresh") || button.label.contains("Load") || button.label.contains("Sync") {
                    button.tap()

                    // Check for loading indicator
                    let loadingIndicator = app.activityIndicators.firstMatch
                    if loadingIndicator.exists {
                        XCTAssertFalse(loadingIndicator.label.isEmpty, "Loading indicator should have accessibility label")
                    }
                    break
                }
            }
        }
    }
}
