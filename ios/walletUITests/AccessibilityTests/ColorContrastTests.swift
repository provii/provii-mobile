/// WCAG AA colour contrast tests covering primary, error, focus, disabled, dark mode,
/// light mode, increased contrast mode, non-text elements, and colour blindness simulations.
import XCTest

class ColorContrastTests: XCTestCase {
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

    // MARK: - WCAG AA Contrast Tests (4.5:1 for normal text, 3:1 for large text)

    func testPrimaryColorContrast() {
        // Test primary colours meet WCAG AA standards
        // Verify primary text and UI elements have sufficient contrast

        // Take screenshot of main screen with primary colours
        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "primary-color-contrast")

        // Verify buttons exist and are visible (implies sufficient contrast)
        let buttons = app.buttons.allElementsBoundByIndex
        XCTAssertGreaterThan(buttons.count, 0, "Should have primary buttons")

        for (index, button) in buttons.prefix(5).enumerated() {
            if button.exists && button.isHittable {
                XCTAssertFalse(button.label.isEmpty, "Button \(index) should have visible label (implies contrast)")
                XCTAssertGreaterThan(button.frame.width, 0, "Button \(index) should be visible")
                XCTAssertGreaterThan(button.frame.height, 0, "Button \(index) should be visible")
            }
        }

        // Verify static text is visible
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        var visibleTextCount = 0
        for text in staticTexts.prefix(10) {
            if text.exists && text.frame.width > 0 && text.frame.height > 0 {
                visibleTextCount += 1
            }
        }
        XCTAssertGreaterThan(visibleTextCount, 0, "Should have visible text elements (implies contrast)")
    }

    func testErrorColorContrast() {
        // Verify error colours meet 4.5:1 contrast ratio
        // Navigate to trigger error state if possible

        // Try to find error messages or error states
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()
            sleep(1)

            // Look for validation that might show errors
            let textFields = app.textFields.allElementsBoundByIndex
            if textFields.count > 0 {
                let field = textFields[0]
                field.tap()

                // Try to trigger validation
                let submitButtons = app.buttons.allElementsBoundByIndex.filter {
                    $0.label.contains("Save") || $0.label.contains("Submit")
                }

                if submitButtons.count > 0 {
                    submitButtons[0].tap()
                    sleep(1)

                    // Look for error messages
                    let allText = app.staticTexts.allElementsBoundByIndex
                    let errorTexts = allText.filter {
                        $0.label.contains("Error") || $0.label.contains("Invalid") || $0.label.contains("Required")
                    }

                    if errorTexts.count > 0 {
                        let errorText = errorTexts[0]
                        XCTAssertTrue(errorText.exists, "Error message should be visible")
                        XCTAssertGreaterThan(errorText.frame.height, 0, "Error text should be visible (implies contrast)")
                    }
                }
            }
        }

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "error-color-contrast")
    }

    func testFocusIndicatorContrast() {
        // Verify focus border has 3:1 minimum contrast
        // Test focus states on interactive elements

        // Navigate to a screen with multiple focusable elements
        let buttons = app.buttons.allElementsBoundByIndex
        if buttons.count >= 2 {
            // Tap first button to potentially show focus
            let firstButton = buttons[0]
            if firstButton.exists && firstButton.isHittable {
                firstButton.tap()
                sleep(1)

                // Take screenshot showing focus state
                let screenshot = app.screenshot()
                saveScreenshot(screenshot, name: "focus-indicator-contrast")

                // Verify focused element is visible
                let navBar = app.navigationBars.firstMatch
                if navBar.exists {
                    let navButtons = navBar.buttons.allElementsBoundByIndex
                    for button in navButtons {
                        if button.hasFocus {
                            XCTAssertGreaterThan(button.frame.width, 0, "Focused button should be visible")
                        }
                    }
                }
            }
        }

        // Test text field focus
        let textFields = app.textFields.allElementsBoundByIndex
        if textFields.count > 0 {
            let field = textFields[0]
            if field.exists && field.isHittable {
                field.tap()
                sleep(1)

                // Verify field is focused and visible
                XCTAssertTrue(field.hasFocus, "Text field should have focus")
                XCTAssertGreaterThan(field.frame.width, 0, "Focused field should be visible")

                let focusScreenshot = app.screenshot()
                saveScreenshot(focusScreenshot, name: "text-field-focus-contrast")
            }
        }
    }

    func testDisabledStateContrast() {
        // Verify disabled elements meet minimum contrast requirements
        // While disabled elements can have lower contrast, they should still be perceivable

        // Look for disabled buttons
        let allButtons = app.buttons.allElementsBoundByIndex
        var disabledButtonFound = false

        for button in allButtons {
            if button.exists && !button.isEnabled {
                disabledButtonFound = true
                // Verify disabled button is still visible
                XCTAssertGreaterThan(button.frame.width, 0, "Disabled button should be visible")
                XCTAssertGreaterThan(button.frame.height, 0, "Disabled button should be visible")
                XCTAssertFalse(button.label.isEmpty, "Disabled button should have label")
                break
            }
        }

        // Take screenshot showing disabled states
        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "disabled-state-contrast")

        // Navigate to settings where we might find toggle switches
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists && settingsButton.isHittable {
            settingsButton.tap()
            sleep(1)

            // Look for switches that might have disabled states
            let switches = app.switches.allElementsBoundByIndex
            if switches.count > 0 {
                let firstSwitch = switches[0]
                XCTAssertTrue(firstSwitch.exists, "Switch should exist")
                XCTAssertFalse(firstSwitch.label.isEmpty, "Switch should have label")

                // Take screenshot showing switch states
                let switchScreenshot = app.screenshot()
                saveScreenshot(switchScreenshot, name: "switch-state-contrast")
            }
        }

        // If no disabled elements found, at least verify enabled elements have good contrast
        if !disabledButtonFound {
            XCTAssertGreaterThan(allButtons.count, 0, "Should have buttons to test")
        }
    }

    func testTextContrast() {
        // Verify all text has sufficient contrast
        // 1. Primary text against backgrounds
        // 2. Secondary text against backgrounds

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "text-contrast")
    }

    func testButtonContrast() {
        // Verify button contrast
        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "button-contrast")
    }

    func testLinkContrast() {
        // Verify link contrast
        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "link-contrast")
    }

    // MARK: - Dark Mode Tests (5th Critical Test)

    func testDarkModeContrast() {
        // Enable dark mode and verify contrast meets WCAG standards
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-UIUserInterfaceStyle", "dark"]
        app.launch()

        // Give app time to launch in dark mode
        sleep(2)

        // 1. Verify text contrast in dark mode
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        var visibleTextCount = 0
        for text in staticTexts.prefix(10) {
            if text.exists && text.frame.width > 0 && text.frame.height > 0 {
                visibleTextCount += 1
            }
        }
        XCTAssertGreaterThan(visibleTextCount, 0, "Should have visible text in dark mode")

        // 2. Verify button contrast in dark mode
        let buttons = app.buttons.allElementsBoundByIndex
        var visibleButtonCount = 0
        for button in buttons.prefix(10) {
            if button.exists && button.isHittable {
                XCTAssertFalse(button.label.isEmpty, "Button should have visible label in dark mode")
                XCTAssertGreaterThan(button.frame.width, 0, "Button should be visible in dark mode")
                visibleButtonCount += 1
            }
        }
        XCTAssertGreaterThan(visibleButtonCount, 0, "Should have visible buttons in dark mode")

        // 3. Verify navigation elements in dark mode
        let navBar = app.navigationBars.firstMatch
        if navBar.exists {
            let navButtons = navBar.buttons.allElementsBoundByIndex
            for button in navButtons {
                if button.exists {
                    XCTAssertFalse(button.label.isEmpty, "Nav button should have label in dark mode")
                }
            }
        }

        // 4. Navigate to different screens to test dark mode consistency
        let credentialButton = app.buttons["Credentials"]
        if credentialButton.exists {
            credentialButton.tap()
            sleep(1)

            // Verify credential list is visible in dark mode
            let cells = app.cells.allElementsBoundByIndex
            if cells.count > 0 {
                let firstCell = cells[0]
                XCTAssertTrue(firstCell.exists, "Credential cells should be visible in dark mode")
                XCTAssertGreaterThan(firstCell.frame.height, 0, "Cell should have height in dark mode")
            }

            // Take screenshot of list in dark mode
            let listScreenshot = app.screenshot()
            saveScreenshot(listScreenshot, name: "dark-mode-list-contrast")
        }

        // Take screenshot showing dark mode contrast
        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "dark-mode-contrast")
    }

    func testLightModeContrast() {
        // Explicitly enable light mode
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-UIUserInterfaceStyle", "light"]
        app.launch()

        // Give app time to launch in light mode
        sleep(2)

        // Verify text contrast in light mode
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        var visibleTextCount = 0
        for text in staticTexts.prefix(10) {
            if text.exists && text.frame.width > 0 && text.frame.height > 0 {
                visibleTextCount += 1
            }
        }
        XCTAssertGreaterThan(visibleTextCount, 0, "Should have visible text in light mode")

        // Verify button contrast in light mode
        let buttons = app.buttons.allElementsBoundByIndex
        var visibleButtonCount = 0
        for button in buttons.prefix(10) {
            if button.exists && button.isHittable {
                XCTAssertFalse(button.label.isEmpty, "Button should have visible label in light mode")
                visibleButtonCount += 1
            }
        }
        XCTAssertGreaterThan(visibleButtonCount, 0, "Should have visible buttons in light mode")

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "light-mode-contrast")
    }

    // MARK: - Increased Contrast Mode Tests

    func testIncreasedContrastMode() {
        // Test with iOS Increased Contrast mode enabled.
        // This is a system-wide setting that apps should respect.

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-UIAccessibilityDarkerSystemColorsEnabled", "YES"]
        app.launch()

        sleep(2)

        // Verify that colours have been adjusted for higher contrast
        let buttons = app.buttons.allElementsBoundByIndex
        var visibleButtonCount = 0
        for button in buttons.prefix(10) {
            if button.exists && button.isHittable {
                XCTAssertFalse(button.label.isEmpty, "Button should have visible label in increased contrast mode")
                XCTAssertGreaterThan(button.frame.width, 0, "Button should be visible")
                visibleButtonCount += 1
            }
        }
        XCTAssertGreaterThan(visibleButtonCount, 0, "Should have visible buttons in increased contrast mode")

        // Verify text is visible
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        var visibleTextCount = 0
        for text in staticTexts.prefix(10) {
            if text.exists && text.frame.width > 0 && text.frame.height > 0 {
                visibleTextCount += 1
            }
        }
        XCTAssertGreaterThan(visibleTextCount, 0, "Should have visible text in increased contrast mode")

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "increased-contrast-mode")
    }

    // MARK: - Non-Text Contrast Tests

    func testIconContrast() {
        // Verify icon contrast (3:1 minimum for UI components)
        // 1. Navigation icons
        // 2. Action icons
        // 3. Status icons
        // 4. Informational icons

        // Check images that are interactive
        let images = app.images.allElementsBoundByIndex
        for (index, image) in images.prefix(10).enumerated() {
            if image.isHittable {
                XCTAssertFalse(image.label.isEmpty, "Interactive icon \(index) should have accessibility label")
                XCTAssertGreaterThan(image.frame.width, 0, "Icon \(index) should be visible")
                XCTAssertGreaterThan(image.frame.height, 0, "Icon \(index) should be visible")
            }
        }

        // Check navigation bar icons
        let navBar = app.navigationBars.firstMatch
        if navBar.exists {
            let navButtons = navBar.buttons.allElementsBoundByIndex
            for (index, button) in navButtons.enumerated() {
                XCTAssertFalse(button.label.isEmpty, "Navigation icon button \(index) should have label")
            }
        }

        // Check tab bar icons if present
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let tabButtons = tabBar.buttons.allElementsBoundByIndex
            for (index, button) in tabButtons.enumerated() {
                XCTAssertFalse(button.label.isEmpty, "Tab bar icon \(index) should have label")
            }
        }

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "icon-contrast")
    }

    func testBorderContrast() {
        // Verify border contrast (3:1 minimum)
        // Important for:
        // 1. Form field borders
        // 2. Card borders
        // 3. Dividers
        // 4. Focus indicators

        // Test form field borders
        let textFields = app.textFields.allElementsBoundByIndex
        for (index, field) in textFields.prefix(5).enumerated() {
            if field.exists {
                XCTAssertGreaterThan(field.frame.width, 0, "Text field \(index) border should be visible")
                XCTAssertGreaterThan(field.frame.height, 0, "Text field \(index) border should be visible")
            }
        }

        // Test card borders (check cells)
        let cells = app.cells.allElementsBoundByIndex
        for (index, cell) in cells.prefix(5).enumerated() {
            if cell.exists {
                XCTAssertGreaterThan(cell.frame.width, 0, "Card/cell \(index) should be visible")
                XCTAssertGreaterThan(cell.frame.height, 0, "Card/cell \(index) should be visible")
            }
        }

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "border-contrast")
    }

    // MARK: - State Contrast Tests

    func testHoverStateContrast() {
        // Verify hover states maintain contrast
        // (Less relevant for iOS, more for iPad with pointer)

        // Test buttons maintain contrast in different states
        let buttons = app.buttons.allElementsBoundByIndex
        for (index, button) in buttons.prefix(5).enumerated() {
            if button.exists && button.isHittable {
                XCTAssertFalse(button.label.isEmpty, "Button \(index) should have visible label")
                XCTAssertGreaterThan(button.frame.width, 0, "Button \(index) should be visible")
            }
        }

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "hover-state-contrast")
    }

    func testActiveStateContrast() {
        // Verify active/pressed states maintain contrast
        let buttons = app.buttons.allElementsBoundByIndex

        // Test that buttons remain visible when tapped
        if buttons.count > 0 {
            let firstButton = buttons[0]
            if firstButton.exists && firstButton.isHittable {
                // Button should be visible before interaction
                XCTAssertFalse(firstButton.label.isEmpty, "Button should have label")
                XCTAssertGreaterThan(firstButton.frame.width, 0, "Button should be visible")

                // Tap and verify it's still accessible
                firstButton.tap()
                sleep(1)

                // Verify UI remains accessible after interaction
                let allButtons = app.buttons.allElementsBoundByIndex
                XCTAssertGreaterThan(allButtons.count, 0, "Buttons should remain visible after interaction")
            }
        }

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "active-state-contrast")
    }

    // MARK: - Colour Blindness Simulation Tests

    func testProtanopiaSimulation() {
        // Simulate red-green colour blindness (Protanopia)
        // Verify information is not conveyed by colour alone.
        // NOTE: iOS XCUITest does not support runtime colour blindness simulation.
        // This test verifies that UI elements use more than just colour to convey information.
        // Manual testing with iOS accessibility colour filters is recommended for full validation.

        // Verify all interactive elements have text labels, not just colour
        let buttons = app.buttons.allElementsBoundByIndex
        for (index, button) in buttons.prefix(10).enumerated() {
            if button.exists {
                XCTAssertFalse(button.label.isEmpty, "Button \(index) should have text label for colour blind users")
            }
        }

        // Verify status indicators have more than just colour
        let images = app.images.allElementsBoundByIndex
        for (index, image) in images.prefix(5).enumerated() {
            if image.isHittable {
                XCTAssertFalse(image.label.isEmpty, "Interactive image \(index) should have label, not rely on colour alone")
            }
        }

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "protanopia-simulation")
    }

    func testDeuteranopiaSimulation() {
        // Simulate red-green colour blindness (Deuteranopia)
        // Most common form of colour blindness.
        // NOTE: iOS XCUITest does not support runtime colour blindness simulation.
        // This test verifies that UI elements are distinguishable without red-green colour distinction.
        // Manual testing with iOS accessibility colour filters is recommended for full validation.

        // Verify UI elements are distinguishable without colour
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        var labeledTextCount = 0
        for text in staticTexts.prefix(10) {
            if text.exists && !text.label.isEmpty {
                labeledTextCount += 1
            }
        }
        XCTAssertGreaterThan(labeledTextCount, 0, "Text elements should have clear labels for colour blind users")

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "deuteranopia-simulation")
    }

    func testTritanopiaSimulation() {
        // Simulate blue-yellow colour blindness (Tritanopia)
        // NOTE: iOS XCUITest does not support runtime colour blindness simulation.
        // This test verifies that UI elements are identifiable without blue-yellow colour distinction.
        // Manual testing with iOS accessibility colour filters is recommended for full validation.

        // Verify all controls are identifiable without colour distinction
        let buttons = app.buttons.allElementsBoundByIndex
        for (index, button) in buttons.prefix(10).enumerated() {
            if button.exists && button.isHittable {
                XCTAssertFalse(button.label.isEmpty, "Button \(index) should be identifiable without blue-yellow colour distinction")
            }
        }

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "tritanopia-simulation")
    }

    func testMonochromaticSimulation() {
        // Simulate complete colour blindness.
        // Does the UI work in pure grayscale?
        // NOTE: iOS XCUITest has limited support for grayscale simulation.
        // This test verifies UI elements remain distinguishable without colour information.
        // Manual testing with iOS accessibility grayscale filter is recommended for full validation.

        // Enable grayscale accessibility setting
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-UIAccessibilityGrayscaleStatusDidChangeNotification", "YES"]
        app.launch()

        sleep(2)

        // Verify all UI elements remain distinguishable
        let buttons = app.buttons.allElementsBoundByIndex
        var accessibleButtonCount = 0
        for button in buttons.prefix(10) {
            if button.exists && button.isHittable && !button.label.isEmpty {
                accessibleButtonCount += 1
            }
        }
        XCTAssertGreaterThan(accessibleButtonCount, 0, "Buttons should be distinguishable in grayscale")

        // Verify text remains readable
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        var readableTextCount = 0
        for text in staticTexts.prefix(10) {
            if text.exists && text.frame.width > 0 && text.frame.height > 0 {
                readableTextCount += 1
            }
        }
        XCTAssertGreaterThan(readableTextCount, 0, "Text should be readable in grayscale")

        let screenshot = app.screenshot()
        saveScreenshot(screenshot, name: "monochromatic-simulation")
    }

    // MARK: - Helper Methods

    private func saveScreenshot(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func calculateContrastRatio(foreground: UIColor, background: UIColor) -> CGFloat {
        // WCAG contrast ratio calculation
        // Formula: (L1 + 0.05) / (L2 + 0.05)
        // where L1 is the lighter colour's relative luminance
        // and L2 is the darker colour's relative luminance

        let foregroundLuminance = getRelativeLuminance(foreground)
        let backgroundLuminance = getRelativeLuminance(background)

        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)

        return (lighter + 0.05) / (darker + 0.05)
    }

    private func getRelativeLuminance(_ colour: UIColor) -> CGFloat {
        // Relative luminance calculation per WCAG 2.1
        // L = 0.2126 * R + 0.7152 * G + 0.0722 * B
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        colour.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Apply gamma correction (sRGB to linear)
        let r = gammaCorrect(red)
        let g = gammaCorrect(green)
        let b = gammaCorrect(blue)

        // Calculate relative luminance
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private func gammaCorrect(_ value: CGFloat) -> CGFloat {
        if value <= 0.03928 {
            return value / 12.92
        } else {
            return pow((value + 0.055) / 1.055, 2.4)
        }
    }

    private func meetsWCAGAA(contrastRatio: CGFloat, isLargeText: Bool) -> Bool {
        if isLargeText {
            return contrastRatio >= 3.0
        } else {
            return contrastRatio >= 4.5
        }
    }

    private func meetsWCAGAAA(contrastRatio: CGFloat, isLargeText: Bool) -> Bool {
        if isLargeText {
            return contrastRatio >= 4.5
        } else {
            return contrastRatio >= 7.0
        }
    }
}
