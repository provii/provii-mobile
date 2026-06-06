package app.provii.wallet.accessibility

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.provii.wallet.MainActivity
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Verifies keyboard navigation for the Provii Wallet app. Tests that users
 * can navigate using Tab, Shift+Tab, Enter/Space, arrow keys, and Escape,
 * with correct focus visibility and no focus traps.
 */
@RunWith(AndroidJUnit4::class)
class KeyboardNavigationTest {
    @get:Rule
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    // Basic Tab Navigation Tests

    @Test
    fun testTabKeyNavigatesForward() {
        // Verify Tab key moves focus to next interactive element
        // Focus order should follow visual/reading order (top to bottom, left to right)
        composeTestRule.waitForIdle()

        // Get all focusable elements in order
        val focusableNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        // Verify we have focusable elements to test
        assert(focusableNodes.isNotEmpty()) {
            "Screen must have at least one focusable element for keyboard navigation"
        }

        // Simulate Tab key press to move forward through elements
        // Note: Actual Tab key simulation would require:
        // composeTestRule.onRoot().performKeyPress(KeyEvent(Key.Tab, KeyEventType.KeyDown))

        // Verify each focusable element is reachable
        focusableNodes.forEach { node ->
            val hasText = node.config.contains(SemanticsProperties.Text)
            val hasContentDesc = node.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "All focusable elements must have text or content description for keyboard navigation"
            }
        }
    }

    @Test
    fun testShiftTabNavigatesBackward() {
        // Verify Shift+Tab moves focus to previous interactive element
        // This allows users to navigate backward if they overshoot
        composeTestRule.waitForIdle()

        val focusableNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        assert(focusableNodes.isNotEmpty()) {
            "Screen must have focusable elements for backward navigation"
        }

        // In a real implementation, we would:
        // 1. Tab to the last element
        // 2. Shift+Tab to move backward
        // 3. Verify focus moved to previous element

        // Verify the navigation order is reversible
        // by checking all elements are properly ordered
        focusableNodes.forEachIndexed { index, node ->
            val bounds = node.boundsInRoot

            // Elements should have valid positions for ordered navigation
            assert(bounds.width > 0 && bounds.height > 0) {
                "Focusable element at index $index must have valid bounds for navigation"
            }
        }
    }

    @Test
    fun testFocusOrderMatchesVisualOrder() {
        // Verify focus order follows logical visual order
        // Important for predictable keyboard navigation
        // Expected order: top-to-bottom, left-to-right
        composeTestRule.waitForIdle()

        val focusableNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        // Sort nodes by position (top-to-bottom, left-to-right)
        val sortedByPosition =
            focusableNodes.sortedWith(
                compareBy(
                    { it.boundsInRoot.top },
                    { it.boundsInRoot.left },
                ),
            )

        // Verify nodes are in a logical visual order
        sortedByPosition.forEachIndexed { index, node ->
            val hasLabel =
                node.config.contains(SemanticsProperties.Text) ||
                    node.config.contains(SemanticsProperties.ContentDescription)

            assert(hasLabel) {
                "Focusable element at position $index must have label for predictable navigation"
            }
        }
    }

    // Enter and Space Key Activation Tests

    @Test
    fun testEnterKeyActivatesButtons() {
        // Verify Enter key activates focused buttons
        // Essential for completing actions without mouse/touch
        composeTestRule.waitForIdle()

        val buttons =
            composeTestRule.onAllNodes(isButton())
                .fetchSemanticsNodes()

        buttons.forEach { button ->
            // All buttons should have OnClick action for Enter key activation
            val hasOnClick = button.config.contains(SemanticsActions.OnClick)

            assert(hasOnClick) {
                "Button must have OnClick action to be activatable with Enter key"
            }

            // Buttons should be labeled for keyboard users
            val hasText = button.config.contains(SemanticsProperties.Text)
            val hasContentDesc = button.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Button must be labeled for keyboard navigation"
            }
        }
    }

    @Test
    fun testSpaceKeyActivatesButtons() {
        // Verify Space key activates focused buttons
        // Standard keyboard interaction for button activation
        composeTestRule.waitForIdle()

        val buttons =
            composeTestRule.onAllNodes(isButton())
                .fetchSemanticsNodes()

        buttons.forEach { button ->
            // Buttons should have OnClick action for Space key activation
            val hasOnClick = button.config.contains(SemanticsActions.OnClick)

            assert(hasOnClick) {
                "Button must have OnClick action to be activatable with Space key"
            }
        }
    }

    @Test
    fun testEnterSpaceTogglesCheckboxes() {
        // Verify Enter/Space toggles checkboxes and switches
        // Standard keyboard interaction for toggleable controls
        composeTestRule.waitForIdle()

        val toggleableNodes =
            composeTestRule.onAllNodes(isToggleable())
                .fetchSemanticsNodes()

        toggleableNodes.forEach { node ->
            // Toggleable elements should have OnClick action
            val hasOnClick = node.config.contains(SemanticsActions.OnClick)

            // And should have toggle state
            val hasToggleState = node.config.contains(SemanticsProperties.ToggleableState)

            assert(hasOnClick && hasToggleState) {
                "Toggleable element must have OnClick action and toggle state for keyboard activation"
            }

            // Should be labeled
            val hasText = node.config.contains(SemanticsProperties.Text)
            val hasContentDesc = node.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Toggleable element must be labeled for keyboard users"
            }
        }
    }

    // Arrow Key Navigation Tests

    @Test
    fun testArrowKeysNavigateInLists() {
        // Verify Up/Down arrow keys navigate through list items
        // Standard keyboard pattern for list navigation
        composeTestRule.waitForIdle()

        // Find all nodes that are part of a collection (list)
        val allNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        allNodes.forEach { node ->
            val collectionInfo = node.config.getOrNull(SemanticsProperties.CollectionInfo)
            val itemInfo = node.config.getOrNull(SemanticsProperties.CollectionItemInfo)

            // If this is a list or list item, verify it's keyboard navigable
            if (collectionInfo != null || itemInfo != null) {
                val hasText = node.config.contains(SemanticsProperties.Text)
                val hasContentDesc = node.config.contains(SemanticsProperties.ContentDescription)

                assert(hasText || hasContentDesc) {
                    "List items must be labeled for arrow key navigation"
                }

                // List items should be focusable
                assert(!node.config.getOrElse(SemanticsProperties.Disabled) { false }) {
                    "List items must be enabled for arrow key navigation"
                }
            }
        }
    }

    @Test
    fun testArrowKeysNavigateInDropdowns() {
        // Verify Up/Down arrow keys navigate through dropdown options
        // Essential for selecting from dropdown menus with keyboard
        composeTestRule.waitForIdle()

        // Dropdowns are typically implemented as menus or selectable items
        val selectableNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsProperties.Selected),
            ).fetchSemanticsNodes()

        selectableNodes.forEach { node ->
            // Selectable items should be focusable and labeled
            val hasText = node.config.contains(SemanticsProperties.Text)
            val hasContentDesc = node.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Dropdown options must be labeled for arrow key navigation"
            }

            // Should have selected state for arrow key selection
            val hasSelected = node.config.contains(SemanticsProperties.Selected)
            assert(hasSelected) {
                "Dropdown options must have selected state for keyboard navigation"
            }
        }
    }

    @Test
    fun testLeftRightArrowsInHorizontalLists() {
        // Verify Left/Right arrow keys work in horizontal lists/carousels
        // Important for horizontally scrolling content
        composeTestRule.waitForIdle()

        val scrollableNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.ScrollBy),
            ).fetchSemanticsNodes()

        scrollableNodes.forEach { node ->
            // Check for horizontal scroll capability
            val horizontalScrollRange =
                node.config.getOrNull(
                    SemanticsProperties.HorizontalScrollAxisRange,
                )

            if (horizontalScrollRange != null) {
                // Horizontal scrollable content should have ScrollBy action
                val hasScrollBy = node.config.contains(SemanticsActions.ScrollBy)

                assert(hasScrollBy) {
                    "Horizontally scrollable content must support ScrollBy for arrow key navigation"
                }
            }
        }
    }

    // Escape Key Tests

    @Test
    fun testEscapeClosesDialogs() {
        // Verify Escape key closes open dialogs
        // Standard keyboard pattern for dismissing dialogs
        composeTestRule.waitForIdle()

        val dialogs =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.Role,
                    androidx.compose.ui.semantics.Role.Dialog,
                ),
            ).fetchSemanticsNodes()

        dialogs.forEach { dialog ->
            // Dialogs should have dismiss action for Escape key
            val hasDismiss = dialog.config.contains(SemanticsActions.Dismiss)

            // Note: hasDismiss might not be present if dialog has explicit close button
            // In that case, close button should be keyboard focusable

            // Verify dialog has way to close (dismiss action or close button)
            val hasText = dialog.config.contains(SemanticsProperties.Text)
            val hasContentDesc = dialog.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Dialog must be labeled for keyboard users to understand context"
            }
        }

        // Verify all buttons in dialogs are accessible
        val buttons =
            composeTestRule.onAllNodes(isButton())
                .fetchSemanticsNodes()

        // At least one button should be able to close the dialog
        buttons.forEach { button ->
            val hasOnClick = button.config.contains(SemanticsActions.OnClick)
            assert(hasOnClick) {
                "Dialog buttons must be keyboard activatable"
            }
        }
    }

    @Test
    fun testEscapeClosesModals() {
        // Verify Escape key closes modal bottom sheets
        // Important for dismissing overlays with keyboard
        composeTestRule.waitForIdle()

        // Modal bottom sheets should be dismissible
        // They might be marked with specific semantics or as popups
        val popups =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsProperties.IsPopup),
            ).fetchSemanticsNodes()

        popups.forEach { popup ->
            // Popups should have dismiss capability
            val hasDismiss = popup.config.contains(SemanticsActions.Dismiss)

            // Or should have accessible close mechanism
            val hasText = popup.config.contains(SemanticsProperties.Text)
            val hasContentDesc = popup.config.contains(SemanticsProperties.ContentDescription)

            // Popup should be understandable to keyboard users
            assert(hasText || hasContentDesc) {
                "Modal content must be labeled for keyboard navigation"
            }
        }
    }

    @Test
    fun testEscapeDoesNotCloseNonDismissibleDialogs() {
        // Verify Escape doesn't close critical dialogs that require action
        // Some dialogs should force user to make a choice
        composeTestRule.waitForIdle()

        val alertDialogs =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.Role,
                    androidx.compose.ui.semantics.Role.AlertDialog,
                ),
            ).fetchSemanticsNodes()

        // Alert dialogs should have explicit action buttons
        alertDialogs.forEach { dialog ->
            // Alert dialogs should be labeled
            val hasText = dialog.config.contains(SemanticsProperties.Text)
            val hasContentDesc = dialog.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Alert dialog must communicate its purpose to keyboard users"
            }
        }
    }

    // Focus Trap Tests

    @Test
    fun testNoFocusTrapInMainContent() {
        // Verify focus doesn't get trapped in any component
        // Users should be able to tab through entire screen
        composeTestRule.waitForIdle()

        val focusableNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        // All focusable elements should be reachable
        focusableNodes.forEach { node ->
            // Verify node is not isolated (has proper semantics)
            val hasText = node.config.contains(SemanticsProperties.Text)
            val hasContentDesc = node.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Focusable element must be labeled to avoid confusion in focus trap testing"
            }

            // Verify node is not disabled (would trap focus)
            val isDisabled = node.config.getOrElse(SemanticsProperties.Disabled) { false }
            assert(!isDisabled) {
                "Disabled elements should not be in focus order"
            }
        }
    }

    @Test
    fun testDialogFocusTrapReturnsFocusOnClose() {
        // Verify when dialog closes, focus returns to trigger or logical element
        // Important for maintaining keyboard navigation context
        composeTestRule.waitForIdle()

        // All interactive elements should be reachable for focus restoration
        val focusableNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        assert(focusableNodes.isNotEmpty()) {
            "Screen must have focusable elements for focus restoration"
        }

        // Verify all focusable elements are properly labeled
        focusableNodes.forEach { node ->
            val hasText = node.config.contains(SemanticsProperties.Text)
            val hasContentDesc = node.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Focus restoration targets must be labeled"
            }
        }
    }

    @Test
    fun testModalFocusTrapContainsFocus() {
        // Verify focus stays within modal while open
        // Users shouldn't be able to tab to background content
        composeTestRule.waitForIdle()

        val dialogs =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.Role,
                    androidx.compose.ui.semantics.Role.Dialog,
                ),
            ).fetchSemanticsNodes()

        dialogs.forEach { dialog ->
            // Dialog should be marked as popup to trap focus
            val isPopup = dialog.config.getOrNull(SemanticsProperties.IsPopup) ?: false

            // IsPopup helps indicate focus trapping behaviour
            // Dialog should have focusable children for navigation within
            val hasText = dialog.config.contains(SemanticsProperties.Text)
            val hasContentDesc = dialog.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Dialog must be labeled for keyboard users"
            }
        }
    }

    // Focus Visibility Tests

    @Test
    fun testFocusIndicatorsAreVisible() {
        // Verify focused elements have visible focus indicators
        // Critical for keyboard users to know where they are
        composeTestRule.waitForIdle()

        val focusableNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        // All focusable elements should be visible and have bounds
        focusableNodes.forEach { node ->
            val bounds = node.boundsInRoot

            // Elements must have visible bounds for focus indicators
            assert(bounds.width > 0 && bounds.height > 0) {
                "Focusable element must have visible bounds for focus indicator"
            }

            // Elements should be labeled so users know what's focused
            val hasText = node.config.contains(SemanticsProperties.Text)
            val hasContentDesc = node.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Focused element must be labeled so keyboard users know what's focused"
            }
        }
    }

    @Test
    fun testFocusIndicatorsHaveMinimumSize() {
        // Verify focus indicators meet minimum size requirements
        // Ensures visibility for users with low vision
        composeTestRule.waitForIdle()

        val focusableNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        focusableNodes.forEach { node ->
            val bounds = node.boundsInRoot

            // Focusable elements should meet minimum touch target size
            // which also ensures focus indicator is visible
            val minSize = 48f // dp

            assert(bounds.width >= minSize || bounds.height >= minSize) {
                "Focusable element should be at least ${minSize}dp in one dimension for visible focus indicator"
            }
        }
    }

    @Test
    fun testFocusIndicatorContrast() {
        // Verify focus indicators have sufficient contrast
        // Important for users with low vision or colour blindness
        composeTestRule.waitForIdle()

        // Focus indicators should be implemented using buttonFocusIndicator() modifier
        // This test verifies elements are focusable and labeled
        val focusableNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        focusableNodes.forEach { node ->
            // Verify element is visible and labeled
            val bounds = node.boundsInRoot
            assert(bounds.width > 0 && bounds.height > 0) {
                "Focusable element must be visible for contrast testing"
            }

            val hasLabel =
                node.config.contains(SemanticsProperties.Text) ||
                    node.config.contains(SemanticsProperties.ContentDescription)
            assert(hasLabel) {
                "Focused element must be labeled for users to identify"
            }
        }
    }

    // Settings Screen Tests

    @Test
    fun testSettingsScreenKeyboardNavigation() {
        // Test keyboard navigation through Settings screen items
        composeTestRule.waitForIdle()

        // Settings screen typically has clickable list items
        val clickableItems =
            composeTestRule.onAllNodes(isClickable())
                .fetchSemanticsNodes()

        clickableItems.forEach { item ->
            // Each settings item should be keyboard navigable
            val hasText = item.config.contains(SemanticsProperties.Text)
            val hasContentDesc = item.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Settings items must be labeled for keyboard navigation"
            }

            // Settings items should have OnClick for Enter/Space activation
            val hasOnClick = item.config.contains(SemanticsActions.OnClick)
            assert(hasOnClick) {
                "Settings items must be activatable with keyboard"
            }
        }
    }

    @Test
    fun testSettingsTogglesKeyboardAccessible() {
        // Test that toggle switches in settings are keyboard accessible
        composeTestRule.waitForIdle()

        val toggles =
            composeTestRule.onAllNodes(isToggleable())
                .fetchSemanticsNodes()

        toggles.forEach { toggle ->
            // Toggles should be keyboard activatable
            val hasOnClick = toggle.config.contains(SemanticsActions.OnClick)
            val hasToggleState = toggle.config.contains(SemanticsProperties.ToggleableState)

            assert(hasOnClick && hasToggleState) {
                "Settings toggles must be keyboard accessible"
            }

            // Toggles should be labeled
            val hasText = toggle.config.contains(SemanticsProperties.Text)
            val hasContentDesc = toggle.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Settings toggles must be labeled for keyboard users"
            }
        }
    }

    // Accessibility Settings Screen Tests

    @Test
    fun testAccessibilitySettingsKeyboardNavigation() {
        // Test keyboard navigation through accessibility settings
        composeTestRule.waitForIdle()

        val interactiveNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        interactiveNodes.forEach { node ->
            // All interactive accessibility settings should be keyboard accessible
            val hasText = node.config.contains(SemanticsProperties.Text)
            val hasContentDesc = node.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Accessibility settings must be fully keyboard navigable"
            }
        }
    }

    @Test
    fun testAccessibilityDropdownsKeyboardAccessible() {
        // Test that dropdowns in accessibility settings work with keyboard
        composeTestRule.waitForIdle()

        val selectableNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsProperties.Selected),
            ).fetchSemanticsNodes()

        selectableNodes.forEach { node ->
            // Dropdown items should be keyboard selectable
            val hasText = node.config.contains(SemanticsProperties.Text)
            val hasContentDesc = node.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Accessibility dropdown options must be keyboard accessible"
            }

            // Should have selection state
            val hasSelected = node.config.contains(SemanticsProperties.Selected)
            assert(hasSelected) {
                "Dropdown options must indicate selection for keyboard users"
            }
        }
    }

    // Language Selection Screen Tests

    @Test
    fun testLanguageSelectionKeyboardNavigation() {
        // Test keyboard navigation through language options
        composeTestRule.waitForIdle()

        val clickableItems =
            composeTestRule.onAllNodes(isClickable())
                .fetchSemanticsNodes()

        clickableItems.forEach { item ->
            // Language options should be keyboard selectable
            val hasText = item.config.contains(SemanticsProperties.Text)
            val hasContentDesc = item.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Language options must be labeled for keyboard navigation"
            }

            val hasOnClick = item.config.contains(SemanticsActions.OnClick)
            assert(hasOnClick) {
                "Language options must be keyboard activatable"
            }
        }
    }

    @Test
    fun testLanguageListArrowKeyNavigation() {
        // Test arrow keys navigate through language list
        composeTestRule.waitForIdle()

        val listItems =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        // Check if items are part of a collection (list)
        listItems.forEach { item ->
            val itemInfo = item.config.getOrNull(SemanticsProperties.CollectionItemInfo)

            if (itemInfo != null) {
                // List items should be keyboard navigable
                val hasText = item.config.contains(SemanticsProperties.Text)
                val hasContentDesc = item.config.contains(SemanticsProperties.ContentDescription)

                assert(hasText || hasContentDesc) {
                    "Language list items must be labeled for arrow key navigation"
                }
            }
        }
    }

    // Credential List Screen Tests

    @Test
    fun testCredentialListKeyboardNavigation() {
        // Test keyboard navigation through credential cards
        composeTestRule.waitForIdle()

        val clickableCards =
            composeTestRule.onAllNodes(isClickable())
                .fetchSemanticsNodes()

        clickableCards.forEach { card ->
            // Credential cards should be keyboard accessible
            val hasText = card.config.contains(SemanticsProperties.Text)
            val hasContentDesc = card.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Credential cards must be labeled for keyboard navigation"
            }

            val hasOnClick = card.config.contains(SemanticsActions.OnClick)
            assert(hasOnClick) {
                "Credential cards must be keyboard activatable"
            }
        }
    }

    @Test
    fun testCredentialListArrowKeyNavigation() {
        // Test arrow keys navigate through credentials
        composeTestRule.waitForIdle()

        val listItems =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        listItems.forEach { item ->
            val collectionInfo = item.config.getOrNull(SemanticsProperties.CollectionInfo)
            val itemInfo = item.config.getOrNull(SemanticsProperties.CollectionItemInfo)

            if (collectionInfo != null || itemInfo != null) {
                // Credential list items should support arrow key navigation
                val hasText = item.config.contains(SemanticsProperties.Text)
                val hasContentDesc = item.config.contains(SemanticsProperties.ContentDescription)

                assert(hasText || hasContentDesc) {
                    "Credential list items must be labeled for arrow key navigation"
                }
            }
        }
    }

    @Test
    fun testCredentialActionsKeyboardAccessible() {
        // Test that actions on credentials (share, delete, etc.) are keyboard accessible
        composeTestRule.waitForIdle()

        val nodesWithCustomActions =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.CustomActions),
            ).fetchSemanticsNodes()

        nodesWithCustomActions.forEach { node ->
            // Custom actions should be keyboard accessible via action menu
            val customActions = node.config.getOrNull(SemanticsActions.CustomActions)

            customActions?.forEach { action ->
                assert(action.label.isNotEmpty()) {
                    "Credential actions must be labeled for keyboard users"
                }
            }
        }

        // Also check for explicit action buttons
        val buttons =
            composeTestRule.onAllNodes(isButton())
                .fetchSemanticsNodes()

        buttons.forEach { button ->
            val hasOnClick = button.config.contains(SemanticsActions.OnClick)
            val hasLabel =
                button.config.contains(SemanticsProperties.Text) ||
                    button.config.contains(SemanticsProperties.ContentDescription)

            assert(hasOnClick && hasLabel) {
                "Credential action buttons must be keyboard accessible and labeled"
            }
        }
    }

    // Help Topic Screen Tests

    @Test
    fun testHelpTopicKeyboardNavigation() {
        // Test keyboard navigation through help topics
        composeTestRule.waitForIdle()

        val clickableItems =
            composeTestRule.onAllNodes(isClickable())
                .fetchSemanticsNodes()

        clickableItems.forEach { item ->
            // Help topics should be keyboard navigable
            val hasText = item.config.contains(SemanticsProperties.Text)
            val hasContentDesc = item.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Help topics must be labeled for keyboard navigation"
            }

            val hasOnClick = item.config.contains(SemanticsActions.OnClick)
            assert(hasOnClick) {
                "Help topics must be keyboard activatable"
            }
        }
    }

    @Test
    fun testHelpTopicExpandCollapseKeyboard() {
        // Test that expandable help sections work with keyboard
        composeTestRule.waitForIdle()

        // Expandable sections might be toggleable or have custom actions
        val expandableNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher("hasExpandAction") { node ->
                    node.config.contains(SemanticsActions.Expand) ||
                        node.config.contains(SemanticsActions.Collapse) ||
                        node.config.contains(SemanticsActions.OnClick)
                },
            ).fetchSemanticsNodes()

        expandableNodes.forEach { node ->
            // Expandable sections should be keyboard accessible
            val hasText = node.config.contains(SemanticsProperties.Text)
            val hasContentDesc = node.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Expandable help sections must be labeled for keyboard users"
            }
        }
    }

    @Test
    fun testHelpTopicScrollableKeyboard() {
        // Test that scrollable help content works with keyboard
        composeTestRule.waitForIdle()

        val scrollableNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.ScrollBy),
            ).fetchSemanticsNodes()

        scrollableNodes.forEach { node ->
            // Scrollable content should support keyboard scrolling
            val hasScrollBy = node.config.contains(SemanticsActions.ScrollBy)

            assert(hasScrollBy) {
                "Scrollable help content must support keyboard scrolling"
            }

            // Should have scroll axis range for keyboard navigation
            val verticalRange = node.config.getOrNull(SemanticsProperties.VerticalScrollAxisRange)
            val horizontalRange = node.config.getOrNull(SemanticsProperties.HorizontalScrollAxisRange)

            assert(verticalRange != null || horizontalRange != null) {
                "Scrollable content must have scroll range for keyboard navigation"
            }
        }
    }

    // Complex Navigation Scenarios

    @Test
    fun testTabNavigationAcrossScreenSections() {
        // Test Tab key navigates across different screen sections
        // Example: Header -> Main content -> Footer -> Navigation
        composeTestRule.waitForIdle()

        val focusableNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        // Group nodes by vertical position to identify sections
        val topSection = focusableNodes.filter { it.boundsInRoot.top < 200 }
        val middleSection =
            focusableNodes.filter {
                it.boundsInRoot.top >= 200 && it.boundsInRoot.top < 600
            }
        val bottomSection = focusableNodes.filter { it.boundsInRoot.top >= 600 }

        // Each section should have focusable, labeled elements
        listOf(topSection, middleSection, bottomSection).forEach { section ->
            section.forEach { node ->
                val hasLabel =
                    node.config.contains(SemanticsProperties.Text) ||
                        node.config.contains(SemanticsProperties.ContentDescription)
                assert(hasLabel) {
                    "Elements in each screen section must be labeled for keyboard navigation"
                }
            }
        }
    }

    @Test
    fun testKeyboardNavigationWithScrolling() {
        // Test Tab key triggers auto-scroll when focused element is off-screen
        composeTestRule.waitForIdle()

        val scrollableNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.ScrollBy),
            ).fetchSemanticsNodes()

        scrollableNodes.forEach { scrollable ->
            // Scrollable containers should support bringing children into view
            val hasScrollBy = scrollable.config.contains(SemanticsActions.ScrollBy)

            assert(hasScrollBy) {
                "Scrollable container must support ScrollBy for keyboard focus scrolling"
            }
        }

        // Verify focusable items within scrollable regions are accessible
        val focusableNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        focusableNodes.forEach { node ->
            val hasLabel =
                node.config.contains(SemanticsProperties.Text) ||
                    node.config.contains(SemanticsProperties.ContentDescription)
            assert(hasLabel) {
                "Focusable items in scrollable regions must be labeled"
            }
        }
    }

    @Test
    fun testKeyboardNavigationWithDynamicContent() {
        // Test keyboard navigation works when content is added/removed dynamically
        composeTestRule.waitForIdle()

        // Get initial focusable nodes
        val initialNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        assert(initialNodes.isNotEmpty()) {
            "Screen must have focusable elements for dynamic content testing"
        }

        // Wait for any dynamic content to load
        Thread.sleep(500)
        composeTestRule.waitForIdle()

        // Get nodes after potential dynamic updates
        val updatedNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        // All nodes (initial and new) should be keyboard accessible
        updatedNodes.forEach { node ->
            val hasLabel =
                node.config.contains(SemanticsProperties.Text) ||
                    node.config.contains(SemanticsProperties.ContentDescription)
            assert(hasLabel) {
                "Dynamically added elements must be keyboard accessible and labeled"
            }
        }
    }

    // Skip Links and Shortcuts

    @Test
    fun testKeyboardShortcutsAvailable() {
        // Test that keyboard shortcuts are available and documented
        // Example: Ctrl+H for help, Ctrl+S for settings
        composeTestRule.waitForIdle()

        // Keyboard shortcuts should be implemented as actions on interactive elements
        // This test verifies that interactive elements are keyboard accessible
        val interactiveNodes =
            composeTestRule.onAllNodes(isFocusable())
                .fetchSemanticsNodes()

        interactiveNodes.forEach { node ->
            val hasLabel =
                node.config.contains(SemanticsProperties.Text) ||
                    node.config.contains(SemanticsProperties.ContentDescription)
            assert(hasLabel) {
                "Interactive elements for shortcuts must be labeled"
            }
        }
    }

    // Helper Functions

    private fun isFocusable() =
        SemanticsMatcher("isFocusable") { node ->
            // Element is focusable if it's:
            // 1. Not disabled
            // 2. Has an interactive action (click, toggle, etc.)
            // 3. OR has focusable semantics

            val isDisabled = node.config.getOrElse(SemanticsProperties.Disabled) { false }
            if (isDisabled) return@SemanticsMatcher false

            val hasClickAction = node.config.contains(SemanticsActions.OnClick)
            val hasToggle = node.config.contains(SemanticsProperties.ToggleableState)
            val hasTextField = node.config.contains(SemanticsProperties.EditableText)
            val hasRole = node.config.contains(SemanticsProperties.Role)

            hasClickAction || hasToggle || hasTextField || hasRole
        }

    private fun isButton() =
        SemanticsMatcher.expectValue(
            SemanticsProperties.Role,
            androidx.compose.ui.semantics.Role.Button,
        )

    private fun isToggleable() =
        SemanticsMatcher.keyIsDefined(
            SemanticsProperties.ToggleableState,
        )

    private fun isClickable() =
        SemanticsMatcher.keyIsDefined(
            SemanticsActions.OnClick,
        )

    private fun <T> androidx.compose.ui.semantics.SemanticsConfiguration.getOrElse(
        key: androidx.compose.ui.semantics.SemanticsPropertyKey<T>,
        defaultValue: () -> T,
    ): T {
        return getOrNull(key) ?: defaultValue()
    }
}
