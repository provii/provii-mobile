package app.provii.wallet.accessibility

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsNode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.*

/**
 * Shared accessibility test helper extensions and matchers for Compose UI tests.
 *
 * Provides assertion functions for content descriptions, heading semantics, touch target
 * sizes, roles, toggle states, live regions, and WCAG colour contrast calculations.
 * Used across the accessibility instrumented test suite.
 */

// Content Description Assertions

/**
 * Asserts that the node has a content description
 */
fun SemanticsNodeInteraction.assertHasContentDescription(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.keyIsDefined(SemanticsProperties.ContentDescription),
    )
}

/**
 * Asserts that the node has a content description containing the specified text
 */
fun SemanticsNodeInteraction.assertContentDescriptionContains(
    text: String,
    substring: Boolean = true,
    ignoreCase: Boolean = false,
): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher("ContentDescription contains '$text'") { node ->
            val description = node.config.getOrNull(SemanticsProperties.ContentDescription)
            description?.contains(text, ignoreCase) ?: false
        },
    )
}

/**
 * Asserts that the node has a content description equal to the specified text
 */
fun SemanticsNodeInteraction.assertContentDescriptionEquals(
    text: String,
): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.expectValue(
            SemanticsProperties.ContentDescription,
            text,
        ),
    )
}

// Heading Assertions

/**
 * Asserts that the node is marked as a heading
 */
fun SemanticsNodeInteraction.assertIsHeading(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading),
    )
}

/**
 * Asserts that the node is NOT marked as a heading
 */
fun SemanticsNodeInteraction.assertIsNotHeading(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.keyNotDefined(SemanticsProperties.Heading),
    )
}

// Touch Target Size Assertions

/**
 * Asserts that the node meets the minimum touch target size (48dp by default)
 */
fun SemanticsNodeInteraction.assertMinimumTouchTarget(
    minSize: Float = 48f,
): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher("hasMinimumTouchTarget($minSize)") { node ->
            val bounds = node.boundsInRoot
            bounds.width >= minSize && bounds.height >= minSize
        },
    )
}

/**
 * Asserts that the node has at least the specified width
 */
fun SemanticsNodeInteraction.assertMinimumWidth(
    minWidth: Float,
): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher("hasMinimumWidth($minWidth)") { node ->
            node.boundsInRoot.width >= minWidth
        },
    )
}

/**
 * Asserts that the node has at least the specified height
 */
fun SemanticsNodeInteraction.assertMinimumHeight(
    minHeight: Float,
): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher("hasMinimumHeight($minHeight)") { node ->
            node.boundsInRoot.height >= minHeight
        },
    )
}

// Role Assertions

/**
 * Asserts that the node has the Button role
 */
fun SemanticsNodeInteraction.assertIsButton(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.expectValue(
            SemanticsProperties.Role,
            androidx.compose.ui.semantics.Role.Button,
        ),
    )
}

/**
 * Asserts that the node has the Checkbox role
 */
fun SemanticsNodeInteraction.assertIsCheckbox(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.expectValue(
            SemanticsProperties.Role,
            androidx.compose.ui.semantics.Role.Checkbox,
        ),
    )
}

/**
 * Asserts that the node has the RadioButton role
 */
fun SemanticsNodeInteraction.assertIsRadioButton(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.expectValue(
            SemanticsProperties.Role,
            androidx.compose.ui.semantics.Role.RadioButton,
        ),
    )
}

/**
 * Asserts that the node has the Switch role
 */
fun SemanticsNodeInteraction.assertIsSwitch(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.expectValue(
            SemanticsProperties.Role,
            androidx.compose.ui.semantics.Role.Switch,
        ),
    )
}

/**
 * Asserts that the node has the Image role
 */
fun SemanticsNodeInteraction.assertIsImage(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.expectValue(
            SemanticsProperties.Role,
            androidx.compose.ui.semantics.Role.Image,
        ),
    )
}

// State Assertions

/**
 * Asserts that the node has a toggle state (on/off)
 */
fun SemanticsNodeInteraction.assertHasToggleState(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.keyIsDefined(SemanticsProperties.ToggleableState),
    )
}

/**
 * Asserts that the node is in the ON state
 */
fun SemanticsNodeInteraction.assertIsOn(): SemanticsNodeInteraction {
    return assert(isToggleable()).assertIsOn()
}

/**
 * Asserts that the node is in the OFF state
 */
fun SemanticsNodeInteraction.assertIsOff(): SemanticsNodeInteraction {
    return assert(isToggleable()).assertIsOff()
}

// Action Assertions

/**
 * Asserts that the node has a click action
 */
fun SemanticsNodeInteraction.assertHasClickAction(): SemanticsNodeInteraction {
    return assert(hasClickAction())
}

/**
 * Asserts that the node has a long click action
 */
fun SemanticsNodeInteraction.assertHasLongClickAction(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.keyIsDefined(SemanticsActions.OnLongClick),
    )
}

/**
 * Asserts that the node has custom actions
 */
fun SemanticsNodeInteraction.assertHasCustomActions(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.keyIsDefined(SemanticsActions.CustomActions),
    )
}

// Live Region Assertions

/**
 * Asserts that the node is marked as a live region
 */
fun SemanticsNodeInteraction.assertIsLiveRegion(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.keyIsDefined(SemanticsProperties.LiveRegion),
    )
}

/**
 * Asserts that the node is a polite live region
 */
fun SemanticsNodeInteraction.assertIsPoliteRegio(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.expectValue(
            SemanticsProperties.LiveRegion,
            androidx.compose.ui.semantics.LiveRegionMode.Polite,
        ),
    )
}

/**
 * Asserts that the node is an assertive live region
 */
fun SemanticsNodeInteraction.assertIsAssertiveLiveRegion(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher.expectValue(
            SemanticsProperties.LiveRegion,
            androidx.compose.ui.semantics.LiveRegionMode.Assertive,
        ),
    )
}

// Text Assertions

/**
 * Asserts that text is not truncated (no ellipsis)
 */
fun SemanticsNodeInteraction.assertTextNotTruncated(): SemanticsNodeInteraction {
    return assert(
        SemanticsMatcher("text is not truncated") { node ->
            val text =
                node.config.getOrNull(SemanticsProperties.Text)
                    ?.firstOrNull()
                    ?.text
            text?.contains("...") != true && text?.contains("\u2026") != true
        },
    )
}

// Semantic Matchers

/**
 * Matcher for nodes with click actions
 */
fun hasClickAction(): SemanticsMatcher {
    return SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick)
}

/**
 * Matcher for nodes with long click actions
 */
fun hasLongClickAction(): SemanticsMatcher {
    return SemanticsMatcher.keyIsDefined(SemanticsActions.OnLongClick)
}

/**
 * Matcher for nodes that are headings
 */
fun isHeading(): SemanticsMatcher {
    return SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading)
}

/**
 * Matcher for nodes that are buttons
 */
fun isButton(): SemanticsMatcher {
    return SemanticsMatcher.expectValue(
        SemanticsProperties.Role,
        androidx.compose.ui.semantics.Role.Button,
    )
}

/**
 * Matcher for nodes that are images
 */
fun isImage(): SemanticsMatcher {
    return SemanticsMatcher.expectValue(
        SemanticsProperties.Role,
        androidx.compose.ui.semantics.Role.Image,
    )
}

/**
 * Matcher for nodes that are text fields
 */
fun isTextField(): SemanticsMatcher {
    return SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText)
}

/**
 * Matcher for nodes that are toggleable
 */
fun isToggleable(): SemanticsMatcher {
    return SemanticsMatcher.keyIsDefined(SemanticsProperties.ToggleableState)
}

/**
 * Matcher for nodes that are clickable (have click action)
 */
fun isClickable(): SemanticsMatcher {
    return hasClickAction()
}

/**
 * Matcher for nodes that are enabled
 */
fun isEnabled(): SemanticsMatcher {
    return SemanticsMatcher("isEnabled") { node ->
        !node.config.getOrElseNullable(SemanticsProperties.Disabled) { false }
    }
}

/**
 * Matcher for nodes that are disabled
 */
fun isDisabled(): SemanticsMatcher {
    return SemanticsMatcher("isDisabled") { node ->
        node.config.getOrElseNullable(SemanticsProperties.Disabled) { false }
    }
}

/**
 * Matcher for nodes with specific content description
 */
fun hasContentDescription(description: String): SemanticsMatcher {
    return SemanticsMatcher.expectValue(
        SemanticsProperties.ContentDescription,
        description,
    )
}

/**
 * Matcher for nodes with content description containing text
 */
fun hasContentDescriptionContaining(
    text: String,
    ignoreCase: Boolean = false,
): SemanticsMatcher {
    return SemanticsMatcher("hasContentDescriptionContaining('$text')") { node ->
        node.config.getOrNull(SemanticsProperties.ContentDescription)
            ?.contains(text, ignoreCase) ?: false
    }
}

// Helper Extensions

/**
 * Gets the content description from a semantics node
 */
fun SemanticsNode.getContentDescription(): String? {
    return config.getOrNull(SemanticsProperties.ContentDescription)
}

/**
 * Gets the text from a semantics node
 */
fun SemanticsNode.getText(): String? {
    return config.getOrNull(SemanticsProperties.Text)
        ?.firstOrNull()
        ?.text
}

/**
 * Gets the role from a semantics node
 */
fun SemanticsNode.getRole(): androidx.compose.ui.semantics.Role? {
    return config.getOrNull(SemanticsProperties.Role)
}

/**
 * Checks if node is a heading
 */
fun SemanticsNode.isHeading(): Boolean {
    return config.contains(SemanticsProperties.Heading)
}

/**
 * Checks if node is enabled
 */
fun SemanticsNode.isEnabled(): Boolean {
    return !config.getOrElseNullable(SemanticsProperties.Disabled) { false }
}

/**
 * Checks if node has content description
 */
fun SemanticsNode.hasContentDescription(): Boolean {
    return config.contains(SemanticsProperties.ContentDescription)
}

/**
 * Gets or else nullable - helper for semantics config
 */
private fun <T> androidx.compose.ui.semantics.SemanticsConfiguration.getOrElseNullable(
    key: androidx.compose.ui.semantics.SemanticsPropertyKey<T>,
    defaultValue: () -> T,
): T {
    return getOrNull(key) ?: defaultValue()
}

// Batch Assertions

/**
 * Asserts that all nodes in the collection meet minimum touch target size
 */
fun SemanticsNodeInteractionCollection.assertAllHaveMinimumTouchTarget(
    minSize: Float = 48f,
): SemanticsNodeInteractionCollection {
    fetchSemanticsNodes().forEachIndexed { index, node ->
        val bounds = node.boundsInRoot
        assert(bounds.width >= minSize && bounds.height >= minSize) {
            "Node at index $index does not meet minimum touch target: " +
                "width=${bounds.width}, height=${bounds.height}, min=$minSize"
        }
    }
    return this
}

/**
 * Asserts that all nodes have content descriptions
 */
fun SemanticsNodeInteractionCollection.assertAllHaveContentDescription(): SemanticsNodeInteractionCollection {
    fetchSemanticsNodes().forEachIndexed { index, node ->
        assert(node.hasContentDescription()) {
            "Node at index $index is missing content description"
        }
    }
    return this
}

/**
 * Asserts that all nodes are enabled
 */
fun SemanticsNodeInteractionCollection.assertAllEnabled(): SemanticsNodeInteractionCollection {
    fetchSemanticsNodes().forEachIndexed { index, node ->
        assert(node.isEnabled()) {
            "Node at index $index is disabled"
        }
    }
    return this
}

// Test Helpers

/**
 * Prints the full semantics tree with accessibility information
 */
fun ComposeUiTest.printAccessibilityTree(tag: String = "ACCESSIBILITY_TREE") {
    onRoot().printToLog(tag)
}

/**
 * Waits for node with content description
 */
fun ComposeUiTest.waitForContentDescription(
    description: String,
    timeoutMillis: Long = 1000L,
): SemanticsNodeInteraction {
    return waitUntil(timeoutMillis) {
        onAllNodes(hasContentDescription(description))
            .fetchSemanticsNodes()
            .isNotEmpty()
    }.let {
        onNode(hasContentDescription(description))
    }
}

/**
 * Waits for a condition to be true
 */
fun ComposeUiTest.waitUntil(
    timeoutMillis: Long = 1000L,
    condition: () -> Boolean,
): Boolean {
    val startTime = System.currentTimeMillis()
    while (System.currentTimeMillis() - startTime < timeoutMillis) {
        if (condition()) return true
        Thread.sleep(50)
    }
    return false
}

// Colour Contrast Helpers

/**
 * Calculate WCAG contrast ratio between two colours
 * Returns ratio from 1:1 (no contrast) to 21:1 (maximum contrast)
 */
fun calculateContrastRatio(
    foreground: Int,
    background: Int,
): Double {
    val l1 = getRelativeLuminance(foreground)
    val l2 = getRelativeLuminance(background)

    val lighter = maxOf(l1, l2)
    val darker = minOf(l1, l2)

    return (lighter + 0.05) / (darker + 0.05)
}

/**
 * Calculate relative luminance for a colour
 */
fun getRelativeLuminance(color: Int): Double {
    val r = android.graphics.Color.red(color) / 255.0
    val g = android.graphics.Color.green(color) / 255.0
    val b = android.graphics.Color.blue(color) / 255.0

    val rLinear = if (r <= 0.03928) r / 12.92 else Math.pow((r + 0.055) / 1.055, 2.4)
    val gLinear = if (g <= 0.03928) g / 12.92 else Math.pow((g + 0.055) / 1.055, 2.4)
    val bLinear = if (b <= 0.03928) b / 12.92 else Math.pow((b + 0.055) / 1.055, 2.4)

    return 0.2126 * rLinear + 0.7152 * gLinear + 0.0722 * bLinear
}

/**
 * Check if contrast ratio meets WCAG AA standard
 */
fun meetsWCAGAA(
    contrastRatio: Double,
    isLargeText: Boolean = false,
): Boolean {
    return if (isLargeText) {
        contrastRatio >= 3.0
    } else {
        contrastRatio >= 4.5
    }
}

/**
 * Check if contrast ratio meets WCAG AAA standard
 */
fun meetsWCAGAAA(
    contrastRatio: Double,
    isLargeText: Boolean = false,
): Boolean {
    return if (isLargeText) {
        contrastRatio >= 4.5
    } else {
        contrastRatio >= 7.0
    }
}
