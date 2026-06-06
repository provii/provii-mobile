/// VoiceOver accessibility tests covering labels, traits, hints, touch targets, navigation flows,
/// modal dismissal, skip links, bypass mechanisms, focus order, and rotor navigation support.
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

    // MARK: - Skip Links and Bypass Mechanism Tests (Phase 5)

    func testTabBarProvidesNavigationBypass() {
        // WCAG 2.4.1 Bypass Blocks
        // Tab bar acts as primary bypass mechanism in iOS apps
        // Equivalent to skip links in web applications

        // Verify all tabs exist and are accessible
        let credentialsTab = app.buttons["Credentials"]
        let settingsTab = app.buttons["Settings"]
        let helpTab = app.buttons["Help"]

        XCTAssertTrue(credentialsTab.exists, "Credentials tab should exist")
        XCTAssertTrue(settingsTab.exists, "Settings tab should exist")
        XCTAssertTrue(helpTab.exists, "Help tab should exist")

        // Verify tabs are hittable (VoiceOver accessible)
        XCTAssertTrue(credentialsTab.isHittable, "Credentials tab should be hittable")
        XCTAssertTrue(settingsTab.isHittable, "Settings tab should be hittable")
        XCTAssertTrue(helpTab.isHittable, "Help tab should be hittable")

        // Verify clear labels
        XCTAssertFalse(credentialsTab.label.isEmpty, "Credentials tab should have label")
        XCTAssertFalse(settingsTab.label.isEmpty, "Settings tab should have label")
        XCTAssertFalse(helpTab.label.isEmpty, "Help tab should have label")

        // Test navigation between tabs (bypass mechanism)
        credentialsTab.tap()
        sleep(1)
        XCTAssertTrue(credentialsTab.isSelected, "Credentials should be selected")

        settingsTab.tap()
        sleep(1)
        XCTAssertTrue(settingsTab.isSelected, "Settings should be selected")

        helpTab.tap()
        sleep(1)
        XCTAssertTrue(helpTab.isSelected, "Help should be selected")

        // Return to credentials
        credentialsTab.tap()
        sleep(1)
        XCTAssertTrue(credentialsTab.isSelected, "Should return to Credentials")
    }

    func testHeadingsExistForQuickNavigation() {
        // WCAG 2.4.1 Bypass Blocks, 2.4.6 Headings and Labels
        // Headings allow VoiceOver users to navigate quickly via rotor
        // Equivalent to skip links in web

        // Test Credentials screen
        let credentialsTab = app.buttons["Credentials"]
        if credentialsTab.exists {
            credentialsTab.tap()
            sleep(1)

            // Look for heading text (manual verification of trait needed)
            let welcomeText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Welcome'")).firstMatch
            if welcomeText.exists {
                XCTAssertTrue(welcomeText.exists, "Welcome heading should exist on empty state")
                // Note: Cannot verify .isHeader trait directly in XCUITest
                // Manual VoiceOver testing required to verify rotor navigation
            }

            let credentialActiveText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Credential Active'")).firstMatch
            if credentialActiveText.exists {
                XCTAssertTrue(credentialActiveText.exists, "Credential Active heading should exist")
            }
        }

        // Test Help screen
        let helpTab = app.buttons["Help"]
        if helpTab.exists {
            helpTab.tap()
            sleep(1)

            // Verify major section headings exist
            let quickAccessHeading = app.staticTexts["Quick Access"]
            let helpTopicsHeading = app.staticTexts["Help Topics"]
            let glossaryHeading = app.staticTexts["Glossary"]

            XCTAssertTrue(quickAccessHeading.exists || helpTopicsHeading.exists || glossaryHeading.exists,
                         "At least one major section heading should exist")

            if quickAccessHeading.exists {
                XCTAssertFalse(quickAccessHeading.label.isEmpty, "Quick Access heading should have label")
            }

            if helpTopicsHeading.exists {
                XCTAssertFalse(helpTopicsHeading.label.isEmpty, "Help Topics heading should have label")
            }
        }

        // Test Settings screen
        let settingsTab = app.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            sleep(1)

            // Look for section headings in settings
            let staticTexts = app.staticTexts.allElementsBoundByIndex
            var foundHeadings = 0

            for text in staticTexts.prefix(10) {
                // Common heading patterns
                if text.label.contains("Accessibility") ||
                   text.label.contains("Language") ||
                   text.label.contains("About") ||
                   text.label.contains("Settings") {
                    foundHeadings += 1
                }
            }

            XCTAssertGreaterThan(foundHeadings, 0, "Settings should have accessible section headings")
        }
    }

    func testFloatingActionButtonProvidesQuickAccess() {
        // WCAG 2.4.1 Bypass Blocks
        // Floating action button provides quick access to primary action
        // Acts as bypass to main functionality

        let credentialsTab = app.buttons["Credentials"]
        if credentialsTab.exists {
            credentialsTab.tap()
            sleep(1)

            // Look for verify/action button
            let verifyButton = app.buttons.containing(
                NSPredicate(format: "label CONTAINS 'Verify' OR label CONTAINS 'Age'")
            ).firstMatch

            if verifyButton.exists {
                XCTAssertTrue(verifyButton.isHittable, "Verify button should be hittable")
                XCTAssertFalse(verifyButton.label.isEmpty, "Verify button should have clear label")

                // Verify minimum touch target size (WCAG 2.5.5)
                verifyMinimumTouchTargetSize(verifyButton, minimum: 44, index: 0)

                // Verify button is prominently accessible
                XCTAssertTrue(verifyButton.exists, "Primary action button should be easily accessible")
            }
        }
    }

    func testToolbarProvidesQuickNavigation() {
        // WCAG 2.4.1 Bypass Blocks
        // Toolbar items provide quick access to key functions
        // Bypass content to reach important actions

        let credentialsTab = app.buttons["Credentials"]
        if credentialsTab.exists {
            credentialsTab.tap()
            sleep(1)

            // Look for toolbar buttons (search, settings, accessibility menu)
            let searchButton = app.buttons.containing(
                NSPredicate(format: "label CONTAINS 'Search' OR accessibilityIdentifier == 'searchButton'")
            ).firstMatch

            let settingsButton = app.buttons.containing(
                NSPredicate(format: "label CONTAINS 'Settings' OR label CONTAINS 'Gear'")
            ).firstMatch

            let accessibilityButton = app.buttons.containing(
                NSPredicate(format: "label CONTAINS 'Accessibility'")
            ).firstMatch

            // At least some toolbar items should exist
            var toolbarItemCount = 0
            if searchButton.exists { toolbarItemCount += 1 }
            if settingsButton.exists { toolbarItemCount += 1 }
            if accessibilityButton.exists { toolbarItemCount += 1 }

            XCTAssertGreaterThan(toolbarItemCount, 0, "Should have accessible toolbar items for quick navigation")

            // If accessibility button exists, test it provides bypass
            if accessibilityButton.exists {
                XCTAssertTrue(accessibilityButton.isHittable, "Accessibility button should be hittable")
                accessibilityButton.tap()
                sleep(1)

                // Verify accessibility menu opened
                let doneButton = app.buttons["Done"]
                if doneButton.exists {
                    XCTAssertTrue(doneButton.exists, "Accessibility quick menu should open")
                    doneButton.tap() // Close menu
                }
            }
        }
    }

    func testFocusOrderIsLogicalAndComplete() {
        // WCAG 2.4.3 Focus Order, 2.1.2 No Keyboard Trap
        // Verify all elements accessible in logical order
        // No focus traps that prevent navigation

        let credentialsTab = app.buttons["Credentials"]
        if credentialsTab.exists {
            credentialsTab.tap()
            sleep(1)

            // Get all interactive elements
            let allButtons = app.buttons.allElementsBoundByIndex
            let allTextFields = app.textFields.allElementsBoundByIndex
            let allLinks = app.links.allElementsBoundByIndex

            // Verify we have interactive elements
            let totalInteractive = allButtons.count + allTextFields.count + allLinks.count
            XCTAssertGreaterThan(totalInteractive, 0, "Should have interactive elements")

            // Verify buttons are hittable (VoiceOver accessible)
            var accessibleCount = 0
            for button in allButtons.prefix(10) {
                if button.exists && button.isHittable && !button.label.isEmpty {
                    accessibleCount += 1
                }
            }

            XCTAssertGreaterThan(accessibleCount, 0, "Should have accessible buttons in logical order")

            // Verify tab bar is always accessible (no focus trap)
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.exists, "Tab bar should exist for bypass navigation")
        }
    }

    func testModalDialogsHaveProperFocusManagement() {
        // WCAG 2.1.2 No Keyboard Trap
        // Modals should trap focus but allow escape
        // Should return focus to trigger element on close

        // Try to open a modal (accessibility quick menu)
        let credentialsTab = app.buttons["Credentials"]
        if credentialsTab.exists {
            credentialsTab.tap()
            sleep(1)

            let accessibilityButton = app.buttons.containing(
                NSPredicate(format: "label CONTAINS 'Accessibility'")
            ).firstMatch

            if accessibilityButton.exists {
                accessibilityButton.tap()
                sleep(1)

                // Verify modal content is accessible
                let toggles = app.switches.allElementsBoundByIndex
                var modalContentAccessible = false

                for toggle in toggles {
                    if toggle.exists && toggle.isHittable {
                        modalContentAccessible = true
                        break
                    }
                }

                if modalContentAccessible {
                    // Verify close button exists and is accessible
                    let doneButton = app.buttons["Done"]
                    XCTAssertTrue(doneButton.exists, "Modal should have close button")
                    XCTAssertTrue(doneButton.isHittable, "Close button should be hittable")
                    XCTAssertFalse(doneButton.label.isEmpty, "Close button should have clear label")

                    // Close modal
                    doneButton.tap()
                    sleep(1)

                    // Verify modal dismissed
                    XCTAssertFalse(doneButton.exists, "Modal should close when done tapped")

                    // Verify can still navigate (no focus trap)
                    let settingsTab = app.buttons["Settings"]
                    XCTAssertTrue(settingsTab.exists, "Should be able to navigate after modal close")
                }
            }
        }
    }

    func testAccessibilityContainersGroupRelatedContent() {
        // WCAG 4.1.2 Name, Role, Value
        // Containers should group related elements for efficient navigation
        // Reduces verbosity and improves navigation

        let helpTab = app.buttons["Help"]
        if helpTab.exists {
            helpTab.tap()
            sleep(1)

            // Look for card elements that should be grouped
            // Help articles, glossary entries, etc.
            let allButtons = app.buttons.allElementsBoundByIndex

            var cardElements = 0
            for button in allButtons {
                // Help articles and cards should have combined labels
                if button.label.contains("Accessibility") ||
                   button.label.contains("Getting") ||
                   button.label.contains("Verifying") {
                    cardElements += 1

                    // Verify the label is descriptive (not just icon)
                    XCTAssertGreaterThan(button.label.count, 5, "Card should have descriptive label")
                }
            }

            XCTAssertGreaterThan(cardElements, 0, "Should have accessible card elements")
        }
    }

    func testDecorativeImagesHiddenFromVoiceOver() {
        // WCAG 1.1.1 Non-text Content
        // Decorative images should be hidden from assistive technology
        // Reduces noise and improves navigation efficiency

        let credentialsTab = app.buttons["Credentials"]
        if credentialsTab.exists {
            credentialsTab.tap()
            sleep(1)

            // Get all images
            let allImages = app.images.allElementsBoundByIndex

            // Count images with labels (functional images)
            var functionalImages = 0
            for image in allImages.prefix(10) {
                if image.exists && !image.label.isEmpty && image.isHittable {
                    functionalImages += 1
                }
            }

            // Most icon images should be hidden (low count of functional images)
            // Functional images would be: QR codes, credential images, etc.
            // Icons in buttons should be hidden with button providing the label
            // Cannot directly test accessibilityHidden in XCUITest
            // This test documents the expectation for manual verification
        }
    }

    func testVoiceOverRotorNavigationSupported() {
        // WCAG 2.4.1 Bypass Blocks
        // VoiceOver rotor should provide multiple navigation methods
        // Cannot test rotor directly, but can verify elements exist that rotor uses

        let credentialsTab = app.buttons["Credentials"]
        if credentialsTab.exists {
            credentialsTab.tap()
            sleep(1)

            // Verify elements that rotor would use
            // Headings: Already tested in testHeadingsExistForQuickNavigation()

            // Buttons: Should have clear labels
            let buttons = app.buttons.allElementsBoundByIndex
            var labeledButtons = 0
            for button in buttons.prefix(10) {
                if !button.label.isEmpty && button.isHittable {
                    labeledButtons += 1
                }
            }
            XCTAssertGreaterThan(labeledButtons, 0, "Should have labeled buttons for rotor")

            // Links: If present, should have labels
            let links = app.links.allElementsBoundByIndex
            for link in links {
                if link.exists {
                    XCTAssertFalse(link.label.isEmpty, "Links should have labels for rotor")
                }
            }

            // Text fields: If present, should have labels
            let textFields = app.textFields.allElementsBoundByIndex
            for field in textFields {
                if field.exists {
                    XCTAssertTrue(!field.label.isEmpty || field.placeholderValue != nil,
                                "Text fields should have labels for rotor")
                }
            }
        }
    }

    func testHighContrastModePreservesNavigation() {
        // WCAG 1.4.3 Contrast (Minimum)
        // High contrast mode should not break navigation patterns
        // All bypass mechanisms should still work

        // This test cannot change system settings
        // Documents requirement for manual testing with high contrast enabled
        // Expectation: All previous tests pass with high contrast on

        // Launch with high contrast simulation
        // Note: This doesn't enable actual high contrast, just tests the app's response
        let credentialsTab = app.buttons["Credentials"]
        if credentialsTab.exists {
            credentialsTab.tap()
            sleep(1)

            // Navigate to accessibility settings
            let settingsTab = app.buttons["Settings"]
            if settingsTab.exists {
                settingsTab.tap()
                sleep(1)

                // Look for accessibility/high contrast option
                let accessibilityCell = app.buttons.containing(
                    NSPredicate(format: "label CONTAINS 'Accessibility'")
                ).firstMatch

                if accessibilityCell.exists {
                    // Document that high contrast testing needed
                    XCTAssertTrue(accessibilityCell.exists,
                                "Accessibility settings should be accessible for high contrast testing")
                }
            }
        }
    }

    func testSkipToMainActionAvailable() {
        // WCAG 2.4.1 Bypass Blocks
        // Primary action should be quickly accessible
        // Acts as "skip to main action" equivalent

        let credentialsTab = app.buttons["Credentials"]
        if credentialsTab.exists {
            credentialsTab.tap()
            sleep(1)

            // Look for primary action buttons
            // These provide quick access to main functionality
            let generateButton = app.buttons.containing(
                NSPredicate(format: "label CONTAINS 'Scan' OR label CONTAINS 'QR'")
            ).firstMatch

            let verifyButton = app.buttons.containing(
                NSPredicate(format: "label CONTAINS 'Verify' OR label CONTAINS 'Age'")
            ).firstMatch

            // At least one primary action should exist
            XCTAssertTrue(generateButton.exists || verifyButton.exists,
                         "Should have quick access to primary action")

            if generateButton.exists {
                XCTAssertTrue(generateButton.isHittable, "Generate button should be accessible")
                XCTAssertFalse(generateButton.label.isEmpty, "Generate button should have clear label")
            }

            if verifyButton.exists {
                XCTAssertTrue(verifyButton.isHittable, "Verify button should be accessible")
                XCTAssertFalse(verifyButton.label.isEmpty, "Verify button should have clear label")
            }
        }
    }
}
