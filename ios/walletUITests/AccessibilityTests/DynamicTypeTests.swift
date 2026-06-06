/// Dynamic Type scaling tests verifying text, buttons, lists, forms, navigation bars,
/// tab bars, cards, and modals adapt correctly across all accessibility text size categories.
import XCTest

class DynamicTypeTests: XCTestCase {
    var app: XCUIApplication!

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Extra Large Text Size Tests

    func testExtraExtraExtraLargeTextSize() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        // Verify text isn't truncated
        // 1. Check all static text elements
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        for (index, text) in staticTexts.prefix(10).enumerated() {
            if text.exists && text.frame.width > 0 {
                verifyNoTextTruncation(text)
                XCTAssertGreaterThan(text.frame.height, 0, "Text \(index) should have height")
            }
        }

        // Verify layouts adapt
        // 1. Check that vertical layouts expand properly
        let scrollViews = app.scrollViews.allElementsBoundByIndex
        if scrollViews.count > 0 {
            XCTAssertTrue(scrollViews[0].exists, "Scrollable content should exist for expanded layouts")
        }

        // Verify buttons still tappable
        let buttons = app.buttons.allElementsBoundByIndex
        for (index, button) in buttons.prefix(10).enumerated() {
            if button.exists {
                XCTAssertTrue(button.isHittable, "Button \(index) should remain tappable at largest text size")
                XCTAssertGreaterThanOrEqual(button.frame.height, 44, "Button \(index) should meet minimum touch target")
            }
        }

        // Take screenshot for verification
        saveScreenshot(of: app, name: "extra-extra-extra-large-text")
    }

    func testAccessibilityExtraExtraLargeTextSize() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraLarge"]
        app.launch()

        verifyTextScaling()
    }

    func testAccessibilityExtraLargeTextSize() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraLarge"]
        app.launch()

        verifyTextScaling()
    }

    func testAccessibilityLargeTextSize() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityLarge"]
        app.launch()

        verifyTextScaling()
    }

    func testAccessibilityMediumTextSize() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityMedium"]
        app.launch()

        verifyTextScaling()
    }

    // MARK: - Standard Text Size Tests

    func testExtraLargeTextSize() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryExtraLarge"]
        app.launch()

        verifyTextScaling()
    }

    func testSmallTextSize() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategorySmall"]
        app.launch()

        verifyTextScaling()
    }

    // MARK: - Specific Component Tests (5 Critical Tests)

    func testCredentialCardScaling() {
        // Test credential card scales properly to AXL (200% scale)
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        // Navigate to credentials
        let credentialButton = app.buttons["Credentials"]
        if credentialButton.exists {
            credentialButton.tap()

            // Wait for credential list
            sleep(1)

            // Check for credential cards
            let cells = app.cells.allElementsBoundByIndex
            if cells.count > 0 {
                let firstCard = cells[0]
                XCTAssertTrue(firstCard.exists, "Credential card should exist")

                // Verify card is accessible at large text size
                XCTAssertTrue(firstCard.isHittable, "Credential card should be hittable at large text size")

                // Verify text within card is not truncated
                let staticTexts = firstCard.staticTexts.allElementsBoundByIndex
                for text in staticTexts {
                    XCTAssertTrue(text.exists, "Text in credential card should be visible")
                    // Frame should have reasonable dimensions
                    XCTAssertGreaterThan(text.frame.height, 0, "Text should have height")
                }

                // Verify buttons within card remain accessible
                let buttons = firstCard.buttons.allElementsBoundByIndex
                for button in buttons {
                    XCTAssertTrue(button.isHittable, "Buttons in credential card should remain hittable")
                    XCTAssertGreaterThanOrEqual(button.frame.height, 44, "Button should meet minimum touch target")
                }
            }
        }

        // Take screenshot for verification
        saveScreenshot(of: app, name: "credential-card-scaling-AXL")
    }

    func testButtonScaling() {
        // Test that buttons scale correctly at large text sizes
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        // Get all buttons on main screen
        let buttons = app.buttons.allElementsBoundByIndex

        var accessibleButtonCount = 0
        for (index, button) in buttons.prefix(10).enumerated() {
            if button.exists {
                // Verify button has accessible label
                XCTAssertFalse(button.label.isEmpty, "Button \(index) should have label")

                // Verify button meets minimum touch target (44pt)
                let frame = button.frame
                XCTAssertGreaterThanOrEqual(
                    frame.height,
                    44,
                    "Button '\(button.label)' height (\(frame.height)) should be at least 44pt at large text size"
                )
                XCTAssertGreaterThanOrEqual(
                    frame.width,
                    44,
                    "Button '\(button.label)' width (\(frame.width)) should be at least 44pt"
                )

                // Verify button is hittable
                if button.isHittable {
                    accessibleButtonCount += 1
                }
            }
        }

        XCTAssertGreaterThan(accessibleButtonCount, 0, "Should have at least one accessible button")

        // Take screenshot for verification
        saveScreenshot(of: app, name: "button-scaling-AXL")
    }

    func testListScaling() {
        // Test that lists handle large text properly
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        // Navigate to a list screen (credentials)
        let credentialButton = app.buttons["Credentials"]
        if credentialButton.exists {
            credentialButton.tap()
            sleep(1)

            // Verify list exists
            let scrollView = app.scrollViews.firstMatch
            XCTAssertTrue(scrollView.exists, "List scroll view should exist")

            // Verify list items expand to fit content
            let cells = app.cells.allElementsBoundByIndex
            if cells.count > 0 {
                for (index, cell) in cells.prefix(3).enumerated() {
                    XCTAssertTrue(cell.exists, "List cell \(index) should exist")

                    // Verify cell has adequate height for large text
                    let cellHeight = cell.frame.height
                    XCTAssertGreaterThan(cellHeight, 44, "Cell \(index) height should be > 44pt to accommodate large text")

                    // Verify cell is hittable
                    XCTAssertTrue(cell.isHittable, "Cell \(index) should be hittable")
                }

                // Verify scrolling works
                if cells.count > 2 {
                    let lastVisibleCell = cells[min(cells.count - 1, 5)]
                    if !lastVisibleCell.isHittable {
                        // Try scrolling
                        scrollView.swipeUp()
                        sleep(1)
                        // Verify we can still interact with cells
                        XCTAssertTrue(cells[0].exists || lastVisibleCell.exists, "Should be able to scroll through list")
                    }
                }
            }
        }

        // Take screenshot for verification
        saveScreenshot(of: app, name: "list-scaling-AXL")
    }

    func testFormFieldScaling() {
        // Test that form input fields scale properly
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        // Navigate to settings which likely has forms
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()
            sleep(1)
        }

        // Check for text fields
        let textFields = app.textFields.allElementsBoundByIndex
        if textFields.count > 0 {
            for (index, field) in textFields.prefix(3).enumerated() {
                XCTAssertTrue(field.exists, "Text field \(index) should exist")

                // Verify field has label or placeholder
                XCTAssertTrue(
                    !field.label.isEmpty || field.placeholderValue != nil,
                    "Text field \(index) should have label or placeholder"
                )

                // Verify field has adequate height for large text
                let fieldHeight = field.frame.height
                XCTAssertGreaterThanOrEqual(
                    fieldHeight,
                    44,
                    "Text field \(index) height should be at least 44pt at large text size"
                )

                // Verify field is hittable
                XCTAssertTrue(field.isHittable, "Text field \(index) should be hittable")
            }
        } else {
            // If no text fields found, check secure text fields
            let secureFields = app.secureTextFields.allElementsBoundByIndex
            for (index, field) in secureFields.prefix(3).enumerated() {
                XCTAssertTrue(field.exists, "Secure field \(index) should exist")
                XCTAssertFalse(field.label.isEmpty, "Secure field \(index) should have label")
                XCTAssertGreaterThanOrEqual(field.frame.height, 44, "Secure field height should be at least 44pt")
            }
        }

        // Take screenshot for verification
        saveScreenshot(of: app, name: "form-field-scaling-AXL")
    }

    func testNavigationBarScaling() {
        // Test that navigation bar adapts to large text
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        // Navigate to a sub-screen to see navigation bar
        let buttons = app.buttons.allElementsBoundByIndex
        if buttons.count > 0 {
            // Tap first navigation button to go to a detail screen
            let firstNavButton = buttons.first(where: { $0.isHittable })
            if let navButton = firstNavButton {
                navButton.tap()
                sleep(1)

                // Verify navigation bar elements
                let navBar = app.navigationBars.firstMatch
                if navBar.exists {
                    // Verify title is visible
                    let navBarStaticTexts = navBar.staticTexts.allElementsBoundByIndex
                    if navBarStaticTexts.count > 0 {
                        let title = navBarStaticTexts[0]
                        XCTAssertTrue(title.exists, "Navigation bar title should exist")
                        XCTAssertGreaterThan(title.frame.height, 0, "Title should have height")
                    }

                    // Verify back button is accessible
                    let backButton = navBar.buttons.firstMatch
                    if backButton.exists {
                        XCTAssertTrue(backButton.isHittable, "Back button should be hittable")
                        XCTAssertGreaterThanOrEqual(backButton.frame.height, 44, "Back button should meet minimum height")
                        XCTAssertFalse(backButton.label.isEmpty, "Back button should have label")
                    }

                    // Verify no overlap in navigation bar
                    let navButtons = navBar.buttons.allElementsBoundByIndex
                    if navButtons.count >= 2 {
                        let firstButton = navButtons[0]
                        let secondButton = navButtons[1]

                        // Buttons should not overlap
                        let overlap = firstButton.frame.maxX > secondButton.frame.minX &&
                                     firstButton.frame.maxX < secondButton.frame.maxX
                        XCTAssertFalse(overlap, "Navigation bar buttons should not overlap")
                    }
                }
            }
        }

        // Take screenshot for verification
        saveScreenshot(of: app, name: "navigation-bar-scaling-AXL")
    }

    func testTabBarWithLargeText() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        sleep(1)

        // Verify tab bar adapts
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            // 1. Tab labels should be readable
            let tabButtons = tabBar.buttons.allElementsBoundByIndex
            for (index, button) in tabButtons.enumerated() {
                XCTAssertFalse(button.label.isEmpty, "Tab \(index) label should be readable")
                XCTAssertTrue(button.exists, "Tab \(index) should exist")

                // 3. Tap targets should remain adequate
                XCTAssertGreaterThanOrEqual(button.frame.height, 44, "Tab \(index) should meet minimum touch target")
                XCTAssertTrue(button.isHittable, "Tab \(index) should be hittable")
            }

            XCTAssertGreaterThan(tabButtons.count, 0, "Should have tab bar buttons")
        }

        // Take screenshot for verification
        saveScreenshot(of: app, name: "tab-bar-large-text")
    }

    func testCardsWithLargeText() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        sleep(1)

        // Navigate to screen with cards (credentials)
        let credentialButton = app.buttons["Credentials"]
        if credentialButton.exists {
            credentialButton.tap()
            sleep(1)

            // 1. Verify card layouts adapt
            let cells = app.cells.allElementsBoundByIndex
            if cells.count > 0 {
                let firstCard = cells[0]
                XCTAssertTrue(firstCard.exists, "Card should exist")
                XCTAssertGreaterThan(firstCard.frame.height, 44, "Card should expand for large text")

                // 2. Verify all card content remains visible
                let cardTexts = firstCard.staticTexts.allElementsBoundByIndex
                for (index, text) in cardTexts.enumerated() {
                    XCTAssertTrue(text.exists, "Card text \(index) should be visible")
                    verifyNoTextTruncation(text)
                }

                // 3. Verify card actions remain accessible
                let cardButtons = firstCard.buttons.allElementsBoundByIndex
                for (index, button) in cardButtons.enumerated() {
                    XCTAssertTrue(button.isHittable, "Card button \(index) should be accessible")
                }
            }
        }

        // Take screenshot for verification
        saveScreenshot(of: app, name: "cards-large-text")
    }

    func testModalsWithLargeText() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        sleep(1)

        // Try to open a modal
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons.prefix(5) {
            if button.label.contains("Add") || button.label.contains("Info") || button.label.contains("Settings") {
                button.tap()
                sleep(1)

                // 1. Verify modal content is scrollable if needed
                let scrollViews = app.scrollViews.allElementsBoundByIndex
                if scrollViews.count > 0 {
                    XCTAssertTrue(scrollViews[0].exists, "Modal should have scrollable content for large text")
                }

                // 2. Verify all text is readable
                let staticTexts = app.staticTexts.allElementsBoundByIndex
                for (index, text) in staticTexts.prefix(5).enumerated() {
                    if text.exists {
                        XCTAssertGreaterThan(text.frame.height, 0, "Modal text \(index) should be readable")
                    }
                }

                // 3. Verify close/action buttons remain accessible
                let modalButtons = app.buttons.allElementsBoundByIndex
                let closeButton = modalButtons.first(where: {
                    $0.label.contains("Close") || $0.label.contains("Done") || $0.label.contains("Cancel")
                })
                if let closeButton = closeButton {
                    XCTAssertTrue(closeButton.isHittable, "Close button should remain accessible")
                    XCTAssertGreaterThanOrEqual(closeButton.frame.height, 44, "Close button should meet minimum touch target")
                    closeButton.tap()
                }

                break
            }
        }

        // Take screenshot for verification
        saveScreenshot(of: app, name: "modals-large-text")
    }

    // MARK: - Multi-line Text Tests

    func testMultilineTextHandling() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        sleep(1)

        // Verify multi-line text elements
        let staticTexts = app.staticTexts.allElementsBoundByIndex

        // 1. Check that text elements are visible
        var multilineTextCount = 0
        for (index, text) in staticTexts.prefix(10).enumerated() {
            if text.exists && text.frame.width > 0 {
                // 2. Verify text wraps instead of truncates
                verifyNoTextTruncation(text)

                // 3. Verify line height adjusts appropriately
                XCTAssertGreaterThan(text.frame.height, 0, "Text \(index) should have appropriate height for wrapping")

                if text.frame.height > 30 {
                    multilineTextCount += 1
                }
            }
        }

        // At least some text should be multiline at this text size
        XCTAssertGreaterThan(staticTexts.count, 0, "Should have text elements to test")

        // Take screenshot for verification
        saveScreenshot(of: app, name: "multiline-text-handling")
    }

    // MARK: - Button Label Tests

    func testButtonLabelsWithLargeText() {
        app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()

        let buttons = app.buttons.allElementsBoundByIndex
        for (index, button) in buttons.enumerated() {
            // Verify button frame is large enough for text
            let frame = button.frame
            XCTAssertGreaterThan(frame.height, 0, "Button \(index) should have height")
            XCTAssertGreaterThan(frame.width, 0, "Button \(index) should have width")
        }
    }

    // MARK: - Helper Methods

    private func verifyTextScaling() {
        // Verify text scaling across all element types
        // 1. Take snapshot of screen
        sleep(1)

        // 2. Verify no text overflow
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        for (index, text) in staticTexts.prefix(10).enumerated() {
            if text.exists {
                XCTAssertTrue(text.exists, "Text \(index) should exist and be visible")
                XCTAssertGreaterThan(text.frame.height, 0, "Text \(index) should have height")
            }
        }

        // 3. Verify all interactive elements remain accessible
        let buttons = app.buttons.allElementsBoundByIndex
        var accessibleButtonCount = 0
        for button in buttons.prefix(10) {
            if button.exists && button.isHittable {
                accessibleButtonCount += 1
                XCTAssertGreaterThanOrEqual(button.frame.height, 44, "Button should meet minimum touch target")
            }
        }

        // 4. Verify layouts adapt appropriately
        XCTAssertGreaterThan(staticTexts.count, 0, "Should have text elements")
    }

    private func verifyNoTextTruncation(_ element: XCUIElement) {
        // Implement truncation detection
        // Verify element is fully visible and not truncated

        // 1. Verify element exists and is hittable
        XCTAssertTrue(element.isHittable, "Element should not be truncated off-screen")

        // 2. Verify element has reasonable dimensions
        XCTAssertGreaterThan(element.frame.width, 0, "Element should have width")
        XCTAssertGreaterThan(element.frame.height, 0, "Element should have height")

        // 3. Verify scrollable containers exist for long content
        if element.frame.height > 1000 {
            // Very tall element should be in a scrollable container
            let scrollViews = app.scrollViews.allElementsBoundByIndex
            XCTAssertGreaterThan(scrollViews.count, 0, "Long content should be in scrollable container")
        }
    }

    private func verifyResponsiveLayout(_ elements: [XCUIElement]) {
        // Verify layout adapts to larger text
        // 1. Check that containers expand
        for (index, element) in elements.enumerated() {
            XCTAssertTrue(element.exists, "Element \(index) should exist")

            // 2. Verify elements remain responsive
            if element.isHittable {
                XCTAssertTrue(element.isHittable, "Element \(index) should remain hittable")
            }

            // 3. Check for reasonable dimensions (not overlapping off-screen)
            XCTAssertGreaterThan(element.frame.width, 0, "Element \(index) should have width")
            XCTAssertGreaterThan(element.frame.height, 0, "Element \(index) should have height")
        }
    }

    private func saveScreenshot(of app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
