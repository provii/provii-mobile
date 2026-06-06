/// Shared accessibility test helpers providing XCTestCase and XCUIElement extensions
/// for touch target verification, label checks, screenshot capture, and focus management.
import XCTest

// MARK: - XCTestCase Extensions

extension XCTestCase {

    // MARK: - Touch Target Size Verification

    /// Verifies that an element meets the minimum touch target size requirements
    /// - Parameters:
    ///   - element: The UI element to check
    ///   - minimum: Minimum size in points (default 44pt per Apple HIG)
    ///   - index: Optional index for error reporting
    func verifyMinimumTouchTargetSize(_ element: XCUIElement, minimum: CGFloat = 44, index: Int? = nil) {
        let frame = element.frame
        let indexStr = index != nil ? " at index \(index!)" : ""

        XCTAssertGreaterThanOrEqual(
            frame.width,
            minimum,
            "Touch target width\(indexStr) too small: \(frame.width) < \(minimum)"
        )
        XCTAssertGreaterThanOrEqual(
            frame.height,
            minimum,
            "Touch target height\(indexStr) too small: \(frame.height) < \(minimum)"
        )
    }

    // MARK: - Accessibility Label Verification

    /// Verifies that an element has an accessibility label containing expected text
    /// - Parameters:
    ///   - element: The UI element to check
    ///   - expectedText: Text that should be in the label
    func verifyAccessibilityLabel(_ element: XCUIElement, contains expectedText: String) {
        XCTAssertTrue(
            element.label.contains(expectedText),
            "Accessibility label '\(element.label)' doesn't contain expected text '\(expectedText)'"
        )
    }

    /// Verifies that an element has an accessibility label
    /// - Parameter element: The UI element to check
    func verifyHasAccessibilityLabel(_ element: XCUIElement) {
        XCTAssertFalse(
            element.label.isEmpty,
            "Element should have an accessibility label"
        )
    }

    /// Verifies that an element's accessibility label matches expected text exactly
    /// - Parameters:
    ///   - element: The UI element to check
    ///   - expectedText: Exact text expected in the label
    func verifyAccessibilityLabel(_ element: XCUIElement, equals expectedText: String) {
        XCTAssertEqual(
            element.label,
            expectedText,
            "Accessibility label doesn't match expected text"
        )
    }

    // MARK: - Accessibility Value Verification

    /// Verifies that an element has an accessibility value
    /// - Parameter element: The UI element to check
    func verifyHasAccessibilityValue(_ element: XCUIElement) {
        XCTAssertNotNil(
            element.value,
            "Element should have an accessibility value"
        )
    }

    /// Verifies that an element's accessibility value contains expected text
    /// - Parameters:
    ///   - element: The UI element to check
    ///   - expectedText: Text that should be in the value
    func verifyAccessibilityValue(_ element: XCUIElement, contains expectedText: String) {
        guard let value = element.value as? String else {
            XCTFail("Element value is not a string")
            return
        }

        XCTAssertTrue(
            value.contains(expectedText),
            "Accessibility value '\(value)' doesn't contain expected text '\(expectedText)'"
        )
    }

    // MARK: - Element Visibility Verification

    /// Verifies that an element is visible and hittable
    /// - Parameter element: The UI element to check
    func verifyElementIsAccessible(_ element: XCUIElement) {
        XCTAssertTrue(element.exists, "Element should exist")
        XCTAssertTrue(element.isHittable, "Element should be hittable")
    }

    /// Verifies that an element exists but is not hittable (e.g., decorative)
    /// - Parameter element: The UI element to check
    func verifyElementIsDecorative(_ element: XCUIElement) {
        XCTAssertTrue(element.exists, "Element should exist")
        XCTAssertFalse(element.isHittable, "Decorative element should not be hittable")
    }

    // MARK: - Focus Management

    /// Waits for an element to receive focus
    /// - Parameters:
    ///   - element: The UI element that should receive focus
    ///   - timeout: Maximum time to wait (default 5 seconds)
    func waitForElementToReceiveFocus(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "hasFocus == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        XCTAssertEqual(result, .completed, "Element did not receive focus within timeout")
    }

    // MARK: - Screenshot Helpers

    /// Takes and saves a screenshot with a descriptive name
    /// - Parameters:
    ///   - app: The application to screenshot
    ///   - name: Name for the screenshot
    ///   - lifetime: Attachment lifetime (default .keepAlways)
    func saveScreenshot(of app: XCUIApplication, name: String, lifetime: XCTAttachment.Lifetime = .keepAlways) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = lifetime
        add(attachment)
    }

    /// Takes a screenshot of a specific element
    /// - Parameters:
    ///   - element: The UI element to screenshot
    ///   - name: Name for the screenshot
    ///   - lifetime: Attachment lifetime (default .keepAlways)
    func saveScreenshot(of element: XCUIElement, name: String, lifetime: XCTAttachment.Lifetime = .keepAlways) {
        let screenshot = element.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = lifetime
        add(attachment)
    }

    // MARK: - Navigation Helpers

    /// Navigates back using the standard back button
    /// - Parameter app: The application instance
    func navigateBack(in app: XCUIApplication) {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.exists, "Back button should exist")
        backButton.tap()
    }

    // MARK: - Text Input Helpers

    /// Types text into a text field with accessibility verification
    /// - Parameters:
    ///   - text: Text to type
    ///   - textField: The text field element
    func accessibleTypeText(_ text: String, into textField: XCUIElement) {
        XCTAssertTrue(textField.exists, "Text field should exist")
        XCTAssertTrue(textField.isHittable, "Text field should be hittable")
        XCTAssertFalse(textField.label.isEmpty, "Text field should have accessibility label")

        textField.tap()
        textField.typeText(text)
    }

    // MARK: - Waiting Helpers

    /// Waits for an element to exist
    /// - Parameters:
    ///   - element: The element to wait for
    ///   - timeout: Maximum time to wait (default 5 seconds)
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element should exist within timeout period")
    }

    /// Waits for an element to disappear
    /// - Parameters:
    ///   - element: The element to wait for disappearance
    ///   - timeout: Maximum time to wait (default 5 seconds)
    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        XCTAssertEqual(result, .completed, "Element should disappear within timeout period")
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {

    /// Checks if this element would meet minimum touch target size
    /// - Parameter minimum: Minimum size in points (default 44)
    /// - Returns: True if element meets minimum size
    func meetsMinimumTouchTargetSize(minimum: CGFloat = 44) -> Bool {
        return frame.width >= minimum && frame.height >= minimum
    }

    /// Gets a user-friendly description of this element for error messages
    var accessibilityDescription: String {
        var parts: [String] = []

        if !label.isEmpty {
            parts.append("label: '\(label)'")
        }

        if let value = value as? String, !value.isEmpty {
            parts.append("value: '\(value)'")
        }

        if let identifier = identifier as String?, !identifier.isEmpty {
            parts.append("identifier: '\(identifier)'")
        }

        parts.append("type: \(elementType.rawValue)")

        return parts.joined(separator: ", ")
    }

    /// Taps an element with accessibility verification
    func accessibleTap() {
        XCTAssertTrue(exists, "Element should exist before tapping: \(accessibilityDescription)")
        XCTAssertTrue(isHittable, "Element should be hittable before tapping: \(accessibilityDescription)")
        tap()
    }

    /// Force taps an element even if not visible (for testing purposes)
    func forceTap() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}

// MARK: - XCUIApplication Extensions

extension XCUIApplication {

    /// Launches the app with VoiceOver simulation
    func launchWithVoiceOver() {
        launchArguments.append("-UIAccessibilityVoiceOverEnabled")
        launchArguments.append("YES")
        launch()
    }

    /// Launches the app with increased contrast mode
    func launchWithIncreasedContrast() {
        launchArguments.append("-UIAccessibilityDarkerSystemColorsEnabled")
        launchArguments.append("YES")
        launch()
    }

    /// Launches the app with reduced transparency
    func launchWithReducedTransparency() {
        launchArguments.append("-UIAccessibilityReduceTransparency")
        launchArguments.append("YES")
        launch()
    }

    /// Launches the app with reduce motion enabled
    func launchWithReducedMotion() {
        launchArguments.append("-UIAccessibilityReduceMotion")
        launchArguments.append("YES")
        launch()
    }

    /// Launches the app in dark mode
    func launchInDarkMode() {
        launchArguments.append("-UIUserInterfaceStyle")
        launchArguments.append("dark")
        launch()
    }

    /// Launches the app in light mode
    func launchInLightMode() {
        launchArguments.append("-UIUserInterfaceStyle")
        launchArguments.append("light")
        launch()
    }

    /// Launches the app with a specific text size
    /// - Parameter category: The content size category
    func launch(withTextSize category: String) {
        launchArguments.append("-UIPreferredContentSizeCategoryName")
        launchArguments.append(category)
        launch()
    }
}

// MARK: - Accessibility Content Size Categories

struct AccessibilityContentSizeCategory {
    static let extraSmall = "UICTContentSizeCategoryExtraSmall"
    static let small = "UICTContentSizeCategorySmall"
    static let medium = "UICTContentSizeCategoryMedium"
    static let large = "UICTContentSizeCategoryLarge"
    static let extraLarge = "UICTContentSizeCategoryExtraLarge"
    static let extraExtraLarge = "UICTContentSizeCategoryExtraExtraLarge"
    static let extraExtraExtraLarge = "UICTContentSizeCategoryExtraExtraExtraLarge"

    static let accessibilityMedium = "UICTContentSizeCategoryAccessibilityMedium"
    static let accessibilityLarge = "UICTContentSizeCategoryAccessibilityLarge"
    static let accessibilityExtraLarge = "UICTContentSizeCategoryAccessibilityExtraLarge"
    static let accessibilityExtraExtraLarge = "UICTContentSizeCategoryAccessibilityExtraExtraLarge"
    static let accessibilityExtraExtraExtraLarge = "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
}
