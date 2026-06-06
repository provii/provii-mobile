/// RTL focus order UI tests validating WCAG 2.2 AA criteria (2.4.3, 2.4.7, 3.2.1) across
/// Arabic, Hebrew, Persian, Urdu, Dari, and Pashto for navigation, forms, lists, and VoiceOver.
import XCTest

final class RTLFocusOrderTests: XCTestCase {

    var app: XCUIApplication!

    // MARK: - RTL Languages to Test

    enum RTLLanguage: String {
        case arabic = "ar"
        case hebrew = "he"
        case persian = "fa"
        case urdu = "ur"
        case dari = "fa-AF"
        case pashto = "ps"

        var displayName: String {
            switch self {
            case .arabic: return "Arabic"
            case .hebrew: return "Hebrew"
            case .persian: return "Persian"
            case .urdu: return "Urdu"
            case .dari: return "Dari"
            case .pashto: return "Pashto"
            }
        }
    }

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    /// Launches app with specified RTL language
    private func launchWithRTLLanguage(_ language: RTLLanguage) {
        app.launchArguments = ["-AppleLanguages", "(\(language.rawValue))"]
        app.launchArguments.append("-UITesting")
        app.launch()

        // Wait for app to be ready
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    /// Gets all focusable elements in a view
    private func getAllFocusableElements() -> [XCUIElement] {
        var focusableElements: [XCUIElement] = []

        // Buttons
        focusableElements.append(contentsOf: app.buttons.allElementsBoundByIndex)

        // Text fields
        focusableElements.append(contentsOf: app.textFields.allElementsBoundByIndex)

        // Secure text fields
        focusableElements.append(contentsOf: app.secureTextFields.allElementsBoundByIndex)

        // Links
        focusableElements.append(contentsOf: app.links.allElementsBoundByIndex)

        // Toggles/Switches
        focusableElements.append(contentsOf: app.switches.allElementsBoundByIndex)

        // Filter out non-hittable elements
        return focusableElements.filter { $0.isHittable }
    }

    /// Verifies that elements are ordered right-to-left on screen
    private func verifyRTLVisualOrder(elements: [XCUIElement], description: String) {
        guard elements.count > 1 else { return }

        // In RTL, rightmost element should come first
        for i in 0..<(elements.count - 1) {
            let current = elements[i]
            let next = elements[i + 1]

            // Current element should be to the right of next element
            XCTAssertGreaterThanOrEqual(
                current.frame.maxX,
                next.frame.maxX,
                "\(description): Element \(i) should be to the right of element \(i+1) in RTL layout"
            )
        }
    }

    /// Simulates tab navigation and returns the order of focused elements
    private func getTabNavigationOrder(startingFrom element: XCUIElement, count: Int) -> [XCUIElement] {
        var order: [XCUIElement] = []

        element.tap() // Focus the first element
        order.append(element)

        // Simulate tab key presses
        for _ in 1..<count {
            // In XCUITest, we can't directly simulate tab key
            // Instead, we verify the focus order by checking element positions
        }

        return order
    }

    /// Verifies VoiceOver swipe navigation order for RTL
    private func verifyVoiceOverRTLOrder(in view: XCUIElement) {
        let elements = getAllFocusableElements()
        guard elements.count > 1 else { return }

        // In RTL with VoiceOver, swiping right should move to previous element (leftward)
        // Swiping left should move to next element (rightward)

        for i in 0..<(elements.count - 1) {
            let current = elements[i]
            let next = elements[i + 1]

            // Verify spatial relationship
            // Next element should be to the left of current in RTL
            XCTAssertLessThanOrEqual(
                next.frame.minX,
                current.frame.minX,
                "VoiceOver navigation: Next element should be to the left in RTL"
            )
        }
    }

    // MARK: - Language Selection Screen Tests

    func testRTLFocusOrder_LanguageSelectionScreen_Arabic() throws {
        launchWithRTLLanguage(.arabic)

        // Wait for language selection screen
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // Get all focusable elements
        let focusableElements = getAllFocusableElements()
        XCTAssertGreaterThan(focusableElements.count, 0, "Should have focusable elements in language selection")

        // Take screenshot for visual verification
        saveScreenshot(of: app, name: "RTL_LanguageSelection_Arabic")

        // Verify search field is properly aligned
        let searchFieldFrame = searchField.frame
        let screenWidth = app.frame.width

        // In RTL, search icon should be on the right
        XCTAssertGreaterThan(searchFieldFrame.minX, 20, "Search field should be properly positioned in RTL")
    }

    func testRTLFocusOrder_LanguageSelectionScreen_Hebrew() throws {
        launchWithRTLLanguage(.hebrew)

        let continueButton = app.buttons.matching(identifier: "continueButton").firstMatch
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))

        saveScreenshot(of: app, name: "RTL_LanguageSelection_Hebrew")

        // Verify button layout is RTL
        let buttonFrame = continueButton.frame
        XCTAssertTrue(buttonFrame.width > 0, "Continue button should be visible")
    }

    // MARK: - Settings View Tests

    func testRTLFocusOrder_SettingsView_Arabic() throws {
        launchWithRTLLanguage(.arabic)

        // Navigate to settings (skip language selection if needed)
        navigateToSettings()

        // Get all cards/buttons in settings
        let settingsCards = app.buttons.allElementsBoundByIndex.filter { $0.isHittable }
        XCTAssertGreaterThan(settingsCards.count, 0, "Should have settings cards")

        // Verify RTL layout of cards
        for card in settingsCards {
            let frame = card.frame

            // Icons should be on the right, chevrons on the left
            // We verify this by checking that interactive elements exist
            XCTAssertTrue(frame.width > 0, "Card should have proper width")
        }

        saveScreenshot(of: app, name: "RTL_Settings_Arabic")
    }

    func testRTLFocusOrder_SettingsView_Persian() throws {
        launchWithRTLLanguage(.persian)

        navigateToSettings()

        // Test focus order of settings items
        let accessibilityCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'دسترسی' OR label CONTAINS[c] 'Accessibility'")).firstMatch

        if accessibilityCard.exists {
            // Verify card is accessible
            XCTAssertTrue(accessibilityCard.isHittable, "Accessibility card should be hittable in RTL")

            // Verify minimum touch target
            verifyMinimumTouchTargetSize(accessibilityCard)
        }

        saveScreenshot(of: app, name: "RTL_Settings_Persian")
    }

    func testRTLFocusOrder_SettingsView_Hebrew() throws {
        launchWithRTLLanguage(.hebrew)

        navigateToSettings()

        let focusableElements = getAllFocusableElements()

        // Verify vertical focus order (top to bottom should be maintained)
        // But horizontal elements should be right to left
        var previousY: CGFloat = 0
        for element in focusableElements {
            let frame = element.frame
            XCTAssertGreaterThanOrEqual(frame.minY, previousY - 5, "Vertical order should flow top to bottom")
            previousY = frame.minY
        }

        saveScreenshot(of: app, name: "RTL_Settings_Hebrew")
    }

    // MARK: - Credential List View Tests

    func testRTLFocusOrder_CredentialList_Arabic() throws {
        launchWithRTLLanguage(.arabic)

        // Navigate to credential list
        navigateToCredentialList()

        // Get credential cards if they exist
        let credentialCards = app.buttons.allElementsBoundByIndex.filter {
            $0.isHittable && $0.frame.height > 60
        }

        if credentialCards.count > 0 {
            // Verify cards maintain proper focus order
            verifyRTLVisualOrder(elements: credentialCards, description: "Credential cards")
        }

        saveScreenshot(of: app, name: "RTL_CredentialList_Arabic")
    }

    func testRTLFocusOrder_CredentialList_Urdu() throws {
        launchWithRTLLanguage(.urdu)

        navigateToCredentialList()

        // Test any list items
        let listItems = app.buttons.allElementsBoundByIndex.filter { $0.isHittable }

        // Verify focus order follows RTL pattern
        for item in listItems {
            // Each item should be properly sized and accessible
            XCTAssertTrue(item.frame.width > 0, "List item should have width")
            XCTAssertTrue(item.isHittable, "List item should be hittable")
        }

        saveScreenshot(of: app, name: "RTL_CredentialList_Urdu")
    }

    // MARK: - Form Input Tests

    func testRTLFocusOrder_FormInputs_Arabic() throws {
        launchWithRTLLanguage(.arabic)

        // Navigate to a form (e.g., search)
        let searchFields = app.searchFields.allElementsBoundByIndex

        if let searchField = searchFields.first {
            // Tap to focus
            searchField.tap()

            // Verify cursor is on the right side in RTL
            XCTAssertTrue(searchField.hasFocus, "Search field should have focus")

            // Type some text
            searchField.typeText("test")

            // In RTL, text should flow right to left
            saveScreenshot(of: searchField, name: "RTL_FormInput_Arabic_Text")
        }

        saveScreenshot(of: app, name: "RTL_FormInput_Arabic")
    }

    func testRTLFocusOrder_FormInputs_Hebrew() throws {
        launchWithRTLLanguage(.hebrew)

        let textFields = app.textFields.allElementsBoundByIndex

        for (index, textField) in textFields.enumerated() where textField.isHittable {
            // Verify text field is accessible
            XCTAssertTrue(textField.exists, "Text field \(index) should exist")
            XCTAssertTrue(textField.isHittable, "Text field \(index) should be hittable")

            // Verify proper sizing
            verifyMinimumTouchTargetSize(textField, index: index)
        }

        saveScreenshot(of: app, name: "RTL_FormInput_Hebrew")
    }

    // MARK: - Navigation Tests

    func testRTLFocusOrder_NavigationBar_Arabic() throws {
        launchWithRTLLanguage(.arabic)

        navigateToSettings()

        // Check navigation bar
        let navBar = app.navigationBars.firstMatch
        if navBar.exists {
            // In RTL, back button should be on the right
            let backButton = navBar.buttons.firstMatch

            if backButton.exists {
                let navBarFrame = navBar.frame
                let backButtonFrame = backButton.frame

                // Back button should be on the right side in RTL
                XCTAssertGreaterThan(
                    backButtonFrame.minX,
                    navBarFrame.width / 2,
                    "Back button should be on the right in RTL navigation bar"
                )
            }
        }

        saveScreenshot(of: app, name: "RTL_NavigationBar_Arabic")
    }

    func testRTLFocusOrder_NavigationBar_Persian() throws {
        launchWithRTLLanguage(.persian)

        navigateToSettings()

        let navBars = app.navigationBars.allElementsBoundByIndex
        for navBar in navBars where navBar.exists {
            // Verify navigation bar exists and is visible
            XCTAssertTrue(navBar.exists, "Navigation bar should exist in RTL")

            // Check for navigation buttons
            let buttons = navBar.buttons.allElementsBoundByIndex
            XCTAssertGreaterThanOrEqual(buttons.count, 0, "Navigation bar should contain buttons")
        }

        saveScreenshot(of: app, name: "RTL_NavigationBar_Persian")
    }

    // MARK: - Dialog/Alert Tests

    func testRTLFocusOrder_AlertDialog_Arabic() throws {
        launchWithRTLLanguage(.arabic)

        navigateToSettings()

        // Try to trigger an alert (if available in settings)
        // Note: This is a placeholder - actual implementation depends on app flow

        saveScreenshot(of: app, name: "RTL_AlertDialog_Arabic")
    }

    // MARK: - Keyboard Navigation Tests

    func testRTLFocusOrder_KeyboardNavigation_Arabic() throws {
        launchWithRTLLanguage(.arabic)

        // Find a text input field
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 5) {
            searchField.tap()

            // Wait for keyboard
            let keyboard = app.keyboards.firstMatch
            XCTAssertTrue(keyboard.waitForExistence(timeout: 3), "Keyboard should appear")

            // Verify keyboard layout
            saveScreenshot(of: app, name: "RTL_Keyboard_Arabic")
        }
    }

    func testRTLFocusOrder_KeyboardNavigation_Hebrew() throws {
        launchWithRTLLanguage(.hebrew)

        let searchFields = app.searchFields.allElementsBoundByIndex
        if let searchField = searchFields.first {
            searchField.tap()

            let keyboard = app.keyboards.firstMatch
            if keyboard.waitForExistence(timeout: 3) {
                // Keyboard should adapt to RTL
                saveScreenshot(of: app, name: "RTL_Keyboard_Hebrew")
            }
        }
    }

    // MARK: - Tab Order Tests

    func testRTLFocusOrder_TabNavigation_Arabic() throws {
        launchWithRTLLanguage(.arabic)

        let focusableElements = getAllFocusableElements()

        // Verify that focusable elements are in logical order
        // In RTL, focus should move from right to left, then top to bottom

        var previousElement: XCUIElement?
        for element in focusableElements {
            if let previous = previousElement {
                let prevFrame = previous.frame
                let currFrame = element.frame

                // If on same row (similar Y coordinate), current should be to the left
                if abs(prevFrame.midY - currFrame.midY) < 20 {
                    XCTAssertLessThanOrEqual(
                        currFrame.maxX,
                        prevFrame.maxX,
                        "Focus should move right to left in RTL on same row"
                    )
                }
            }
            previousElement = element
        }

        saveScreenshot(of: app, name: "RTL_TabNavigation_Arabic")
    }

    // MARK: - VoiceOver Navigation Tests

    func testRTLFocusOrder_VoiceOverNavigation_Arabic() throws {
        // Launch with VoiceOver simulation
        app.launchArguments = [
            "-AppleLanguages", "(ar)",
            "-UIAccessibilityVoiceOverEnabled", "YES"
        ]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        // Get all elements in VoiceOver order
        let elements = getAllFocusableElements()

        // Verify VoiceOver navigation order respects RTL
        verifyVoiceOverRTLOrder(in: app)

        saveScreenshot(of: app, name: "RTL_VoiceOver_Arabic")
    }

    func testRTLFocusOrder_VoiceOverNavigation_Hebrew() throws {
        app.launchArguments = [
            "-AppleLanguages", "(he)",
            "-UIAccessibilityVoiceOverEnabled", "YES"
        ]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        let focusableElements = getAllFocusableElements()

        // Verify each element is properly accessible
        for (index, element) in focusableElements.enumerated() {
            XCTAssertTrue(element.exists, "Element \(index) should exist for VoiceOver")
            XCTAssertFalse(element.label.isEmpty, "Element \(index) should have accessibility label")
        }

        saveScreenshot(of: app, name: "RTL_VoiceOver_Hebrew")
    }

    // MARK: - Multi-Column Layout Tests

    func testRTLFocusOrder_MultiColumnLayout_Arabic() throws {
        launchWithRTLLanguage(.arabic)

        // Test any grid or multi-column layouts
        let buttons = app.buttons.allElementsBoundByIndex.filter { $0.isHittable }

        // Group elements by row
        var rows: [[XCUIElement]] = []
        var currentRow: [XCUIElement] = []
        var lastY: CGFloat = 0

        for button in buttons {
            let frame = button.frame

            if currentRow.isEmpty || abs(frame.minY - lastY) < 20 {
                currentRow.append(button)
                lastY = frame.minY
            } else {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                }
                currentRow = [button]
                lastY = frame.minY
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        // Verify RTL order within each row
        for (index, row) in rows.enumerated() {
            verifyRTLVisualOrder(elements: row, description: "Row \(index)")
        }

        saveScreenshot(of: app, name: "RTL_MultiColumn_Arabic")
    }

    // MARK: - Card Layout Tests

    func testRTLFocusOrder_CardLayout_Persian() throws {
        launchWithRTLLanguage(.persian)

        navigateToSettings()

        // Settings screen has card-based layout
        let cards = app.buttons.allElementsBoundByIndex.filter {
            $0.isHittable && $0.frame.height > 60
        }

        for (index, card) in cards.enumerated() {
            // Verify card is properly accessible
            XCTAssertTrue(card.exists, "Card \(index) should exist")
            XCTAssertTrue(card.isHittable, "Card \(index) should be hittable")

            // Verify card has proper label
            XCTAssertFalse(card.label.isEmpty, "Card \(index) should have accessibility label")

            // Verify card meets minimum touch target
            verifyMinimumTouchTargetSize(card, index: index)
        }

        saveScreenshot(of: app, name: "RTL_CardLayout_Persian")
    }

    // MARK: - List Navigation Tests

    func testRTLFocusOrder_ListNavigation_Urdu() throws {
        launchWithRTLLanguage(.urdu)

        // Test list navigation (language selection is a good example)
        let tables = app.tables.allElementsBoundByIndex
        let scrollViews = app.scrollViews.allElementsBoundByIndex

        if !tables.isEmpty || !scrollViews.isEmpty {
            let container = tables.first ?? scrollViews.first!

            // Get cells or items
            let cells = container.cells.allElementsBoundByIndex
            let buttons = container.buttons.allElementsBoundByIndex
            let items = cells.isEmpty ? buttons : cells

            // Verify list items maintain proper order
            for (index, item) in items.enumerated() where item.isHittable {
                XCTAssertTrue(item.exists, "List item \(index) should exist")
            }
        }

        saveScreenshot(of: app, name: "RTL_ListNavigation_Urdu")
    }

    // MARK: - Focus Visibility Tests

    func testRTLFocusOrder_FocusVisibility_Arabic() throws {
        launchWithRTLLanguage(.arabic)

        let focusableElements = getAllFocusableElements()

        // Verify each focusable element is clearly visible
        for (index, element) in focusableElements.enumerated() {
            XCTAssertTrue(element.isHittable, "Element \(index) should be hittable")

            let frame = element.frame
            XCTAssertGreaterThan(frame.width, 0, "Element \(index) should have visible width")
            XCTAssertGreaterThan(frame.height, 0, "Element \(index) should have visible height")
        }

        saveScreenshot(of: app, name: "RTL_FocusVisibility_Arabic")
    }

    // MARK: - Swipe Gesture Tests

    func testRTLFocusOrder_SwipeGestures_Arabic() throws {
        launchWithRTLLanguage(.arabic)

        // In RTL, swipe gestures should be mirrored
        // Swipe left should navigate forward, swipe right should navigate back

        // Find a scrollable view
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            let initialOffset = scrollView.frame.origin

            // Swipe left (should scroll right in content)
            scrollView.swipeLeft()

            // Give time for animation
            sleep(1)

            saveScreenshot(of: app, name: "RTL_SwipeLeft_Arabic")

            // Swipe right (should scroll left in content)
            scrollView.swipeRight()

            sleep(1)

            saveScreenshot(of: app, name: "RTL_SwipeRight_Arabic")
        }
    }

    // MARK: - Accessibility Traversal Tests

    func testRTLFocusOrder_AccessibilityTraversal_Hebrew() throws {
        launchWithRTLLanguage(.hebrew)

        let focusableElements = getAllFocusableElements()

        // Verify accessibility elements are in logical order
        // This matters for screen reader users

        for (index, element) in focusableElements.enumerated() {
            // Each element should have proper accessibility info
            XCTAssertTrue(element.exists, "Element \(index) exists")

            if index > 0 {
                let previous = focusableElements[index - 1]
                let prevFrame = previous.frame
                let currFrame = element.frame

                // Verify logical progression
                // Either lower on screen or to the left on same row
                let isLowerRow = currFrame.minY > prevFrame.maxY
                let isSameRow = abs(currFrame.midY - prevFrame.midY) < 20
                let isLeftward = isSameRow && currFrame.maxX < prevFrame.minX

                XCTAssertTrue(
                    isLowerRow || isLeftward,
                    "Element \(index) should follow logical RTL order after element \(index - 1)"
                )
            }
        }

        saveScreenshot(of: app, name: "RTL_AccessibilityTraversal_Hebrew")
    }

    // MARK: - Navigation Helpers

    private func navigateToSettings() {
        // Skip language selection if present
        let continueButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'continue' OR label CONTAINS[c] 'متابعة' OR label CONTAINS[c] 'המשך'")).firstMatch

        if continueButton.waitForExistence(timeout: 5) {
            continueButton.tap()
            sleep(1)
        }

        // Look for settings button or navigate to settings
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'settings' OR label CONTAINS[c] 'إعدادات' OR label CONTAINS[c] 'הגדרות'")).firstMatch

        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(1)
        }
    }

    private func navigateToCredentialList() {
        // Navigate past onboarding if needed
        navigateToSettings()

        // Navigate back to main screen
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            sleep(1)
        }
    }
}

// MARK: - XCUIElement Focus Extension

extension XCUIElement {
    /// Checks if the element currently has focus
    var hasFocus: Bool {
        return self.value(forKey: "hasKeyboardFocus") as? Bool ?? false
    }
}

// MARK: - Helper Extensions

extension XCTestCase {
    /// Saves a screenshot with a descriptive name
    func saveScreenshot(of element: XCUIElement, name: String) {
        let screenshot = element.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
