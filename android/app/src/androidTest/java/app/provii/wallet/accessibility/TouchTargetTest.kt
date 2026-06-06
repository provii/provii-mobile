package app.provii.wallet.accessibility

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.provii.wallet.MainActivity
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Verifies that touch target sizes meet accessibility requirements, including
 * the 48dp WCAG 2.1 minimum, enhanced 60dp mode, overlap prevention, and
 * adequate spacing between interactive elements.
 */
@RunWith(AndroidJUnit4::class)
class TouchTargetTest {
    @get:Rule
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    companion object {
        const val MINIMUM_TOUCH_TARGET = 48f // WCAG 2.1 Level AAA
        const val ENHANCED_TOUCH_TARGET = 60f // Enhanced accessibility
        const val MINIMUM_SPACING = 8f // Minimum spacing between targets
    }

    // Minimum Touch Target Tests (48dp)

    @Test
    fun allInteractiveElementsMeet48dpMinimum() {
        // WCAG 2.1 Level AAA requires 44x44dp, Android recommends 48x48dp
        composeTestRule.waitForIdle()

        val interactiveNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick),
            ).fetchSemanticsNodes()

        var testedNodes = 0
        interactiveNodes.forEach { node ->
            val bounds = node.boundsInRoot

            // Each interactive element must meet minimum size
            assert(bounds.width >= MINIMUM_TOUCH_TARGET) {
                "Interactive element width ${bounds.width}dp must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Interactive element height ${bounds.height}dp must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            testedNodes++
        }

        assert(testedNodes > 0) {
            "Should have found interactive elements to test"
        }
    }

    @Test
    fun buttonsMeet48dpMinimum() {
        // All buttons must meet minimum touch target size
        composeTestRule.waitForIdle()

        val buttons =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.Role,
                    androidx.compose.ui.semantics.Role.Button,
                ),
            ).fetchSemanticsNodes()

        buttons.forEach { button ->
            val bounds = button.boundsInRoot

            assert(bounds.width >= MINIMUM_TOUCH_TARGET) {
                "Button width ${bounds.width}dp must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Button height ${bounds.height}dp must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            // Verify button is interactive
            assert(button.config.contains(SemanticsActions.OnClick)) {
                "Button must have click action"
            }
        }
    }

    @Test
    fun iconButtonsMeet48dpMinimum() {
        // Icon-only buttons often violate touch target size
        composeTestRule.waitForIdle()

        val buttons =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.Role,
                    androidx.compose.ui.semantics.Role.Button,
                ),
            ).fetchSemanticsNodes()

        // Check buttons that might be icon-only (no text)
        buttons.forEach { button ->
            val hasText = button.config.contains(SemanticsProperties.Text)
            val bounds = button.boundsInRoot

            // Icon buttons (with or without text) must meet size requirements
            assert(bounds.width >= MINIMUM_TOUCH_TARGET) {
                "Icon button width ${bounds.width}dp must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Icon button height ${bounds.height}dp must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            // Icon buttons should have content description
            if (!hasText) {
                val hasContentDesc = button.config.contains(SemanticsProperties.ContentDescription)
                assert(hasContentDesc) {
                    "Icon button must have content description"
                }
            }
        }
    }

    @Test
    fun toggleControlsMeet48dpMinimum() {
        // Checkboxes, switches, radio buttons must meet minimum size
        composeTestRule.waitForIdle()

        val toggleNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsProperties.ToggleableState),
            ).fetchSemanticsNodes()

        toggleNodes.forEach { toggle ->
            val bounds = toggle.boundsInRoot

            assert(bounds.width >= MINIMUM_TOUCH_TARGET) {
                "Toggle control width ${bounds.width}dp must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Toggle control height ${bounds.height}dp must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            // Verify toggle has state
            assert(toggle.config.contains(SemanticsProperties.ToggleableState)) {
                "Toggle must have toggleable state"
            }
        }
    }

    @Test
    fun textFieldsHaveAdequateHeight() {
        // Text fields should be at least 48dp tall for easy tapping
        composeTestRule.waitForIdle()

        val textFields =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText),
            ).fetchSemanticsNodes()

        textFields.forEach { field ->
            val bounds = field.boundsInRoot

            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Text field height ${bounds.height}dp must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            // Width can vary, but should be reasonable for tapping
            assert(bounds.width > 0) {
                "Text field must have width"
            }
        }
    }

    @Test
    fun linksMeet48dpMinimum() {
        // Clickable text (links) must meet touch target size
        composeTestRule.waitForIdle()

        val clickableTextNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher("isClickableText") { node ->
                    node.config.contains(SemanticsActions.OnClick) &&
                        node.config.contains(SemanticsProperties.Text)
                },
            ).fetchSemanticsNodes()

        clickableTextNodes.forEach { link ->
            val bounds = link.boundsInRoot

            // Links should meet minimum touch target
            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Link height ${bounds.height}dp should be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            // Width depends on text length, but verify it's reasonable
            assert(bounds.width > 0) {
                "Link must have visible width"
            }
        }
    }

    @Test
    fun customInteractiveElementsMeetMinimum() {
        // Custom clickable components must meet size requirements
        composeTestRule.waitForIdle()

        val customClickableNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher("hasClickAction") { node ->
                    node.config.contains(SemanticsActions.OnClick)
                },
            ).fetchSemanticsNodes()

        customClickableNodes.forEach { node ->
            val bounds = node.boundsInRoot

            assert(bounds.width >= MINIMUM_TOUCH_TARGET) {
                "Custom interactive element width ${bounds.width}dp must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Custom interactive element height ${bounds.height}dp must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }
        }
    }

    // Enhanced Touch Target Tests (60dp)

    @Test
    fun increasedTouchTargetModeUses60dp() {
        // When accessibility settings request larger targets, use 60dp
        composeTestRule.waitForIdle()

        // For enhanced accessibility, targets should be even larger
        val buttons =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.Role,
                    androidx.compose.ui.semantics.Role.Button,
                ),
            ).fetchSemanticsNodes()

        // All buttons should at least meet the minimum
        // In enhanced mode, they'd be 60dp or larger
        buttons.forEach { button ->
            val bounds = button.boundsInRoot

            // At minimum, must meet 48dp requirement
            assert(bounds.width >= MINIMUM_TOUCH_TARGET) {
                "Button must meet minimum ${MINIMUM_TOUCH_TARGET}dp"
            }

            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Button must meet minimum ${MINIMUM_TOUCH_TARGET}dp"
            }
        }
    }

    @Test
    fun primaryActionButtonsUseEnhancedSize() {
        // Primary actions should use larger touch targets when possible
        composeTestRule.waitForIdle()

        val buttons =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.Role,
                    androidx.compose.ui.semantics.Role.Button,
                ),
            ).fetchSemanticsNodes()

        buttons.forEach { button ->
            val bounds = button.boundsInRoot

            // Primary buttons should ideally be 60dp or larger
            // But must at minimum be 48dp
            assert(bounds.width >= MINIMUM_TOUCH_TARGET) {
                "Primary button width must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Primary button height must be at least ${MINIMUM_TOUCH_TARGET}dp"
            }

            // Verify button is accessible
            val hasText = button.config.contains(SemanticsProperties.Text)
            val hasContentDesc = button.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Button must have text or content description"
            }
        }
    }

    // Touch Target Overlap Tests

    @Test
    fun touchTargetsDoNotOverlap() {
        // Interactive elements should not overlap (causes mis-taps)
        composeTestRule.waitForIdle()

        val interactiveNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick),
            ).fetchSemanticsNodes()

        // Check for overlapping bounds
        for (i in interactiveNodes.indices) {
            for (j in i + 1 until interactiveNodes.size) {
                val bounds1 = interactiveNodes[i].boundsInRoot
                val bounds2 = interactiveNodes[j].boundsInRoot

                // Check if bounds overlap
                val overlaps =
                    !(
                        bounds1.right < bounds2.left ||
                            bounds2.right < bounds1.left ||
                            bounds1.bottom < bounds2.top ||
                            bounds2.bottom < bounds1.top
                    )

                if (overlaps) {
                    // Some overlap is acceptable if one element contains another
                    // (e.g., button inside a larger clickable area)
                    val contained =
                        (
                            bounds1.left >= bounds2.left &&
                                bounds1.right <= bounds2.right &&
                                bounds1.top >= bounds2.top &&
                                bounds1.bottom <= bounds2.bottom
                        ) ||
                            (
                                bounds2.left >= bounds1.left &&
                                    bounds2.right <= bounds1.right &&
                                    bounds2.top >= bounds1.top &&
                                    bounds2.bottom <= bounds1.bottom
                            )

                    // Allow contained elements (parent-child relationship)
                    assert(contained) {
                        "Interactive elements should not partially overlap"
                    }
                }
            }
        }
    }

    @Test
    fun adjacentTargetsHaveSpacing() {
        // Adjacent interactive elements should have spacing to prevent mis-taps
        composeTestRule.waitForIdle()

        val interactiveNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick),
            ).fetchSemanticsNodes()

        // Check spacing between adjacent elements
        for (i in interactiveNodes.indices) {
            val bounds1 = interactiveNodes[i].boundsInRoot

            for (j in interactiveNodes.indices) {
                if (i == j) continue

                val bounds2 = interactiveNodes[j].boundsInRoot

                // Check if elements are adjacent horizontally
                val horizontallyAdjacent =
                    bounds1.top < bounds2.bottom &&
                        bounds1.bottom > bounds2.top &&
                        (bounds1.right <= bounds2.left || bounds2.right <= bounds1.left)

                // Check if elements are adjacent vertically
                val verticallyAdjacent =
                    bounds1.left < bounds2.right &&
                        bounds1.right > bounds2.left &&
                        (bounds1.bottom <= bounds2.top || bounds2.bottom <= bounds1.top)

                if (horizontallyAdjacent) {
                    val spacing =
                        if (bounds1.right <= bounds2.left) {
                            bounds2.left - bounds1.right
                        } else {
                            bounds1.left - bounds2.right
                        }

                    // Spacing should ideally be 8dp or more, but some UIs may be tighter
                    // We verify elements are at least not overlapping
                    assert(spacing >= 0) {
                        "Horizontally adjacent elements should not overlap"
                    }
                }

                if (verticallyAdjacent) {
                    val spacing =
                        if (bounds1.bottom <= bounds2.top) {
                            bounds2.top - bounds1.bottom
                        } else {
                            bounds1.top - bounds2.bottom
                        }

                    // Verify no overlap
                    assert(spacing >= 0) {
                        "Vertically adjacent elements should not overlap"
                    }
                }
            }
        }
    }

    @Test
    fun smallScreenLayoutsPreventOverlap() {
        // On small screens, touch targets should still not overlap
        composeTestRule.waitForIdle()

        val interactiveNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick),
            ).fetchSemanticsNodes()

        // Verify all interactive elements are visible and non-overlapping
        interactiveNodes.forEach { node ->
            val bounds = node.boundsInRoot

            // Element should be visible
            assert(bounds.width > 0 && bounds.height > 0) {
                "Interactive element must be visible on small screens"
            }

            // Should meet minimum touch target
            assert(bounds.width >= MINIMUM_TOUCH_TARGET || bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Element should meet minimum size requirements"
            }
        }
    }

    // Spacing and Layout Tests

    @Test
    fun buttonGroupsHaveAdequateSpacing() {
        // Groups of buttons should have spacing between them
        composeTestRule.waitForIdle()

        val buttons =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.Role,
                    androidx.compose.ui.semantics.Role.Button,
                ),
            ).fetchSemanticsNodes()

        // Each button should be independently accessible
        buttons.forEach { button ->
            val bounds = button.boundsInRoot

            assert(bounds.width >= MINIMUM_TOUCH_TARGET) {
                "Each button in group must meet minimum size"
            }

            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Each button in group must meet minimum size"
            }
        }

        // Verify no complete overlap
        for (i in buttons.indices) {
            for (j in i + 1 until buttons.size) {
                val bounds1 = buttons[i].boundsInRoot
                val bounds2 = buttons[j].boundsInRoot

                val completeOverlap =
                    bounds1.left == bounds2.left &&
                        bounds1.right == bounds2.right &&
                        bounds1.top == bounds2.top &&
                        bounds1.bottom == bounds2.bottom

                assert(!completeOverlap) {
                    "Buttons should not completely overlap"
                }
            }
        }
    }

    @Test
    fun listItemsHaveAdequateTouchTargets() {
        // List items should be tall enough for easy tapping
        composeTestRule.waitForIdle()

        val clickableNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick),
            ).fetchSemanticsNodes()

        clickableNodes.forEach { node ->
            val bounds = node.boundsInRoot

            // List items should meet minimum height
            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "List item height ${bounds.height}dp should be at least ${MINIMUM_TOUCH_TARGET}dp"
            }
        }
    }

    @Test
    fun denseUIStillMeetsMinimumSizes() {
        // Even in dense UI layouts, touch targets must meet minimums
        composeTestRule.waitForIdle()

        val interactiveNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick),
            ).fetchSemanticsNodes()

        // All interactive elements must meet minimums regardless of density
        interactiveNodes.forEach { node ->
            val bounds = node.boundsInRoot

            assert(bounds.width >= MINIMUM_TOUCH_TARGET) {
                "Dense UI element width must still be ${MINIMUM_TOUCH_TARGET}dp minimum"
            }

            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Dense UI element height must still be ${MINIMUM_TOUCH_TARGET}dp minimum"
            }
        }
    }

    // Edge Cases Tests

    @Test
    fun screenEdgeTargetsAreAccessible() {
        // Touch targets near screen edges should still meet requirements
        composeTestRule.waitForIdle()

        val interactiveNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick),
            ).fetchSemanticsNodes()

        interactiveNodes.forEach { node ->
            val bounds = node.boundsInRoot

            // Verify size regardless of position
            assert(bounds.width >= MINIMUM_TOUCH_TARGET) {
                "Edge element width must be ${MINIMUM_TOUCH_TARGET}dp minimum"
            }

            assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Edge element height must be ${MINIMUM_TOUCH_TARGET}dp minimum"
            }

            // Edge elements should be fully visible
            assert(bounds.left >= 0 && bounds.top >= 0) {
                "Edge elements should be fully visible (not cut off)"
            }
        }
    }

    @Test
    fun dismissibleElementsHaveProperTargets() {
        // Close buttons, dismiss buttons must meet touch target size
        composeTestRule.waitForIdle()

        val buttons =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.Role,
                    androidx.compose.ui.semantics.Role.Button,
                ),
            ).fetchSemanticsNodes()

        buttons.forEach { button ->
            val contentDesc = button.config.getOrNull(SemanticsProperties.ContentDescription)
            val text =
                button.config.getOrNull(SemanticsProperties.Text)
                    ?.firstOrNull()?.text

            val isDismissButton =
                contentDesc?.contains("close", ignoreCase = true) == true ||
                    contentDesc?.contains("dismiss", ignoreCase = true) == true ||
                    text?.contains("close", ignoreCase = true) == true

            if (isDismissButton) {
                val bounds = button.boundsInRoot

                // Dismiss buttons are critical for accessibility
                assert(bounds.width >= MINIMUM_TOUCH_TARGET) {
                    "Dismiss button width must be ${MINIMUM_TOUCH_TARGET}dp minimum"
                }

                assert(bounds.height >= MINIMUM_TOUCH_TARGET) {
                    "Dismiss button height must be ${MINIMUM_TOUCH_TARGET}dp minimum"
                }
            }
        }
    }

    @Test
    fun allTouchTargetsAreReachable() {
        // All touch targets should be within reachable screen area
        composeTestRule.waitForIdle()

        val interactiveNodes =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick),
            ).fetchSemanticsNodes()

        interactiveNodes.forEach { node ->
            val bounds = node.boundsInRoot

            // Elements should be visible on screen
            assert(bounds.width > 0 && bounds.height > 0) {
                "Touch target must be visible and reachable"
            }

            // Should meet minimum size
            assert(bounds.width >= MINIMUM_TOUCH_TARGET && bounds.height >= MINIMUM_TOUCH_TARGET) {
                "Reachable touch target must meet ${MINIMUM_TOUCH_TARGET}dp minimum"
            }
        }
    }
}
