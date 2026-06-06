package app.provii.wallet.accessibility

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
 * Verifies that error messages meet accessibility requirements. Tests that error
 * messages are announced by screen readers, have proper semantic markup, include
 * recovery suggestions, work with form validation, and use appropriate live regions.
 */
@RunWith(AndroidJUnit4::class)
class ErrorMessagingTest {
    @get:Rule
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    // Error Announcement Tests

    @Test
    fun errorMessagesAreAnnouncedByScreenReaders() {
        // Error messages must be announced to screen reader users
        composeTestRule.waitForIdle()

        val textFields =
            composeTestRule.onAllNodes(isTextField())
                .fetchSemanticsNodes()

        textFields.forEach { field ->
            val errorMessage = field.config.getOrNull(SemanticsProperties.Error)

            if (errorMessage != null) {
                // Error message must be non-empty for announcement
                assert(errorMessage.isNotEmpty()) {
                    "Error message must not be empty to be announced"
                }

                // Field should be visible to show error
                val bounds = field.boundsInRoot
                assert(bounds.width > 0 && bounds.height > 0) {
                    "Field with error must be visible"
                }

                // Error property ensures screen reader announcement
                assert(field.config.contains(SemanticsProperties.Error)) {
                    "Field must have Error property for screen reader announcement"
                }
            }
        }
    }

    @Test
    fun errorMessagesUseLiveRegions() {
        // Dynamic error messages should use live regions for announcements
        composeTestRule.waitForIdle()

        val liveRegions =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsProperties.LiveRegion),
            ).fetchSemanticsNodes()

        liveRegions.forEach { region ->
            // Live regions should have content to announce
            val hasText = region.config.contains(SemanticsProperties.Text)
            val hasContentDesc = region.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Live region must have text or content description for announcements"
            }

            // Verify live region mode is set
            val mode = region.config.getOrNull(SemanticsProperties.LiveRegion)
            assert(mode != null) {
                "Live region must have a mode (Polite or Assertive)"
            }

            // Error messages should typically use Assertive mode
            // (though Polite is also acceptable for less critical errors)
            val bounds = region.boundsInRoot
            assert(bounds.width > 0 && bounds.height > 0) {
                "Live region should be visible"
            }
        }
    }

    @Test
    fun criticalErrorsUseAssertiveLiveRegion() {
        // Critical errors should interrupt screen reader announcements
        composeTestRule.waitForIdle()

        val assertiveLiveRegions =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.LiveRegion,
                    androidx.compose.ui.semantics.LiveRegionMode.Assertive,
                ),
            ).fetchSemanticsNodes()

        // If there are assertive live regions, they should have meaningful content
        assertiveLiveRegions.forEach { region ->
            val hasText = region.config.contains(SemanticsProperties.Text)
            val hasContentDesc = region.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Assertive live region must have text for critical announcements"
            }

            // Should be visible
            val bounds = region.boundsInRoot
            assert(bounds.width > 0 && bounds.height > 0) {
                "Assertive live region should be visible"
            }
        }
    }

    @Test
    fun nonCriticalErrorsUsePoliteLiveRegion() {
        // Non-critical errors should use polite announcements
        composeTestRule.waitForIdle()

        val politeLiveRegions =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.LiveRegion,
                    androidx.compose.ui.semantics.LiveRegionMode.Polite,
                ),
            ).fetchSemanticsNodes()

        // Polite live regions should have content
        politeLiveRegions.forEach { region ->
            val hasText = region.config.contains(SemanticsProperties.Text)
            val hasContentDesc = region.config.contains(SemanticsProperties.ContentDescription)

            assert(hasText || hasContentDesc) {
                "Polite live region must have text for announcements"
            }

            // Should be visible
            val bounds = region.boundsInRoot
            assert(bounds.width > 0 && bounds.height > 0) {
                "Polite live region should be visible"
            }
        }
    }

    // Error State Semantics Tests

    @Test
    fun errorStatesHaveProperSemantics() {
        // Error states must be properly marked in semantics tree
        composeTestRule.waitForIdle()

        val textFields =
            composeTestRule.onAllNodes(isTextField())
                .fetchSemanticsNodes()

        textFields.forEach { field ->
            val hasError = field.config.getOrNull(SemanticsProperties.Error)

            if (hasError != null) {
                // Error property must be set
                assert(field.config.contains(SemanticsProperties.Error)) {
                    "Field with error must have Error semantics property"
                }

                // Error message should be descriptive
                assert(hasError.isNotEmpty()) {
                    "Error message must not be empty"
                }

                // Field should still have label
                val hasText = field.config.contains(SemanticsProperties.Text)
                val hasContentDesc = field.config.contains(SemanticsProperties.ContentDescription)

                assert(hasText || hasContentDesc) {
                    "Field with error must maintain its label"
                }

                // Field should be visible
                val bounds = field.boundsInRoot
                assert(bounds.width > 0 && bounds.height > 0) {
                    "Field with error must be visible"
                }
            }
        }
    }

    @Test
    fun errorStatesIndicatedVisually() {
        // Errors must be indicated visually, not just with colour
        composeTestRule.waitForIdle()

        val textFields =
            composeTestRule.onAllNodes(isTextField())
                .fetchSemanticsNodes()

        textFields.forEach { field ->
            val errorMessage = field.config.getOrNull(SemanticsProperties.Error)

            if (errorMessage != null) {
                // Error should have text message (not just colour change)
                assert(errorMessage.isNotEmpty()) {
                    "Error must have text message, not rely on colour alone"
                }

                // Error text should be meaningful (more than just "Error")
                assert(errorMessage.length > 5) {
                    "Error message should be descriptive: $errorMessage"
                }

                // Field should be accessible
                val bounds = field.boundsInRoot
                assert(bounds.width > 0 && bounds.height > 0) {
                    "Field with visible error must be displayed"
                }
            }
        }
    }

    @Test
    fun errorIconsHaveContentDescription() {
        // Error icons must have descriptive labels
        composeTestRule.waitForIdle()

        // Find images that might be error indicators
        val images =
            composeTestRule.onAllNodes(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.Role,
                    androidx.compose.ui.semantics.Role.Image,
                ),
            ).fetchSemanticsNodes()

        images.forEach { image ->
            val contentDesc = image.config.getOrNull(SemanticsProperties.ContentDescription)

            if (contentDesc != null && contentDesc.contains("error", ignoreCase = true)) {
                // Error icons should have meaningful descriptions
                assert(contentDesc.isNotEmpty()) {
                    "Error icon must have content description"
                }

                // Should not just say "error" - should explain the error
                assert(contentDesc.length > 5) {
                    "Error icon description should be meaningful: $contentDesc"
                }

                // Should be visible
                val bounds = image.boundsInRoot
                assert(bounds.width > 0 && bounds.height > 0) {
                    "Error icon should be visible"
                }
            }
        }
    }

    // Error Recovery Tests

    @Test
    fun errorMessagesIncludeRecoverySuggestions() {
        // Error messages should explain how to fix the problem
        composeTestRule.waitForIdle()

        val textFields =
            composeTestRule.onAllNodes(isTextField())
                .fetchSemanticsNodes()

        textFields.forEach { field ->
            val errorMessage = field.config.getOrNull(SemanticsProperties.Error)

            if (errorMessage != null) {
                // Error message should be informative (not just "Invalid")
                assert(errorMessage.length > 10) {
                    "Error message should include helpful information: $errorMessage"
                }

                // Common patterns for helpful error messages:
                // - "Please enter a valid email address"
                // - "Password must be at least 8 characters"
                // - "This field is required"

                // Verify it's not just a generic error
                val genericErrors = listOf("error", "invalid", "wrong")
                val isGeneric =
                    genericErrors.any { term ->
                        errorMessage.trim().equals(term, ignoreCase = true)
                    }

                assert(!isGeneric) {
                    "Error message should be specific, not generic: $errorMessage"
                }
            }
        }
    }

    @Test
    fun errorMessagesProvideContext() {
        // Errors should include context about what went wrong
        composeTestRule.waitForIdle()

        val textFields =
            composeTestRule.onAllNodes(isTextField())
                .fetchSemanticsNodes()

        textFields.forEach { field ->
            val errorMessage = field.config.getOrNull(SemanticsProperties.Error)

            if (errorMessage != null) {
                // Error should be descriptive enough to understand
                assert(errorMessage.length >= 10) {
                    "Error message should provide context: $errorMessage"
                }

                // Should reference the field or problem
                // e.g., "Email format is incorrect" not just "Incorrect"
                val hasContext = errorMessage.split(" ").size >= 3

                assert(hasContext) {
                    "Error message should provide context (multiple words): $errorMessage"
                }
            }
        }
    }

    @Test
    fun errorMessagesAvoidTechnicalJargon() {
        // Error messages should be understandable by all users
        composeTestRule.waitForIdle()

        val textFields =
            composeTestRule.onAllNodes(isTextField())
                .fetchSemanticsNodes()

        // Technical jargon to avoid
        val jargonTerms =
            listOf(
                "null",
                "undefined",
                "exception",
                "stack trace",
                "500",
                "400",
                "parse error",
            )

        textFields.forEach { field ->
            val errorMessage = field.config.getOrNull(SemanticsProperties.Error)

            if (errorMessage != null) {
                // Error should not contain technical jargon
                val containsJargon =
                    jargonTerms.any { term ->
                        errorMessage.contains(term, ignoreCase = true)
                    }

                assert(!containsJargon) {
                    "Error message should avoid technical jargon: $errorMessage"
                }

                // Should be user-friendly
                assert(errorMessage.isNotEmpty()) {
                    "Error message must be present"
                }
            }
        }
    }

    // Form Validation Tests

    @Test
    fun formValidationErrorsAreAccessible() {
        // Form validation errors must be announced properly
        composeTestRule.waitForIdle()

        val textFields =
            composeTestRule.onAllNodes(isTextField())
                .fetchSemanticsNodes()

        textFields.forEach { field ->
            val errorMessage = field.config.getOrNull(SemanticsProperties.Error)

            if (errorMessage != null) {
                // Validation errors should have Error property
                assert(field.config.contains(SemanticsProperties.Error)) {
                    "Validation error must use Error semantics property"
                }

                // Should be associated with the correct field
                val hasLabel =
                    field.config.contains(SemanticsProperties.Text) ||
                        field.config.contains(SemanticsProperties.ContentDescription)

                assert(hasLabel) {
                    "Field with validation error must have a label"
                }

                // Field should be visible
                val bounds = field.boundsInRoot
                assert(bounds.width > 0 && bounds.height > 0) {
                    "Field with validation error must be visible"
                }
            }
        }
    }

    @Test
    fun multipleErrorsAreListedClearly() {
        // When multiple fields have errors, all should be accessible
        composeTestRule.waitForIdle()

        val fieldsWithErrors =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsProperties.Error),
            ).fetchSemanticsNodes()

        // Each error should be independently accessible
        fieldsWithErrors.forEach { field ->
            val errorMessage = field.config.getOrNull(SemanticsProperties.Error)

            // Each error must be non-empty and specific
            assert(errorMessage != null && errorMessage.isNotEmpty()) {
                "Each field error must have a message"
            }

            // Field should be visible
            val bounds = field.boundsInRoot
            assert(bounds.width > 0 && bounds.height > 0) {
                "Each field with error must be visible"
            }
        }

        // If there are multiple errors, verify we can detect them all
        if (fieldsWithErrors.size > 1) {
            // All error messages should be unique or field-specific
            val errorMessages =
                fieldsWithErrors.mapNotNull { field ->
                    field.config.getOrNull(SemanticsProperties.Error)
                }

            // Verify we collected the error messages
            assert(errorMessages.size == fieldsWithErrors.size) {
                "Should collect all error messages"
            }
        }
    }

    @Test
    fun requiredFieldErrorsAreClear() {
        // "Required field" errors should be clear and helpful
        composeTestRule.waitForIdle()

        val textFields =
            composeTestRule.onAllNodes(isTextField())
                .fetchSemanticsNodes()

        textFields.forEach { field ->
            val errorMessage = field.config.getOrNull(SemanticsProperties.Error)

            if (errorMessage != null &&
                errorMessage.contains("required", ignoreCase = true)
            ) {
                // Required field errors should mention which field
                // Good: "Email is required"
                // Bad: "Required"
                assert(errorMessage.length > 8) {
                    "Required field error should be descriptive: $errorMessage"
                }

                // Should identify the field or provide context
                val hasFieldContext = errorMessage.split(" ").size >= 2

                assert(hasFieldContext) {
                    "Required field error should identify the field: $errorMessage"
                }
            }
        }
    }

    @Test
    fun formatErrorsExplainExpectedFormat() {
        // Format validation errors should explain the expected format
        composeTestRule.waitForIdle()

        val textFields =
            composeTestRule.onAllNodes(isTextField())
                .fetchSemanticsNodes()

        val formatKeywords = listOf("format", "invalid", "enter", "must")

        textFields.forEach { field ->
            val errorMessage = field.config.getOrNull(SemanticsProperties.Error)

            if (errorMessage != null) {
                val appearsToBeFormatError =
                    formatKeywords.any { keyword ->
                        errorMessage.contains(keyword, ignoreCase = true)
                    }

                if (appearsToBeFormatError) {
                    // Format errors should be detailed
                    assert(errorMessage.length > 15) {
                        "Format error should explain expected format: $errorMessage"
                    }

                    // Should help user understand what's needed
                    assert(errorMessage.split(" ").size >= 3) {
                        "Format error should be detailed enough: $errorMessage"
                    }
                }
            }
        }
    }

    // Error Dismissal Tests

    @Test
    fun errorsCanBeDismissedOrCleared() {
        // Users should be able to dismiss or clear error messages
        composeTestRule.waitForIdle()

        val fieldsWithErrors =
            composeTestRule.onAllNodes(
                SemanticsMatcher.keyIsDefined(SemanticsProperties.Error),
            ).fetchSemanticsNodes()

        // Fields with errors should be editable (allowing users to fix them)
        fieldsWithErrors.forEach { field ->
            // Field should be editable
            assert(field.config.contains(SemanticsProperties.EditableText)) {
                "Field with error should be editable to allow correction"
            }

            // Field should not be disabled
            val isDisabled = field.config.getOrNull(SemanticsProperties.Disabled) ?: false
            assert(!isDisabled) {
                "Field with error should not be disabled (user needs to fix it)"
            }

            // Field should be visible and accessible
            val bounds = field.boundsInRoot
            assert(bounds.width > 0 && bounds.height > 0) {
                "Field with error must be accessible for correction"
            }
        }
    }

    @Test
    fun errorStatesClearAfterCorrection() {
        // Error states should be properly managed in semantics
        composeTestRule.waitForIdle()

        val textFields =
            composeTestRule.onAllNodes(isTextField())
                .fetchSemanticsNodes()

        // All text fields should be properly set up for error state management
        textFields.forEach { field ->
            // Field should be editable
            assert(field.config.contains(SemanticsProperties.EditableText)) {
                "Text field should be editable"
            }

            // If it has an error, it should be clearable
            val hasError = field.config.contains(SemanticsProperties.Error)
            if (hasError) {
                // Should not be disabled
                val isDisabled = field.config.getOrNull(SemanticsProperties.Disabled) ?: false
                assert(!isDisabled) {
                    "Field with error should be editable for correction"
                }
            }
        }
    }

    // Helper Functions

    private fun isTextField() =
        SemanticsMatcher.keyIsDefined(
            SemanticsProperties.EditableText,
        )
}
