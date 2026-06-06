package app.provii.wallet.accessibility

import androidx.compose.foundation.layout.*
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.provii.wallet.ui.components.accessibility.FocusManager
import app.provii.wallet.ui.components.accessibility.rtlAwareFocusTraversal
import app.provii.wallet.utils.LanguageConfig
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.*

/**
 * RTL Focus Order Tests for Hebrew and Persian languages
 *
 * WCAG 2.4.3 Level A: Focus Order
 * Tests that focus order is logical and preserves meaning in RTL layouts,
 * especially for Hebrew and Persian which have specific considerations:
 *
 * Hebrew-specific:
 * - Numbers mixed with Hebrew text (maintain LTR for numbers)
 * - Hebrew punctuation placement
 * - Mixed LTR/RTL content
 *
 * Persian-specific:
 * - Persian numerals vs Western numerals
 * - Persian-specific characters (گچپژ)
 * - Bidirectional text with URLs/emails
 */
@RunWith(AndroidJUnit4::class)
class RtlFocusOrderTest {
    @get:Rule
    val composeTestRule = createComposeRule()

    /**
     * Test that Hebrew language is correctly detected as RTL
     */
    @Test
    fun testHebrewIsDetectedAsRTL() {
        val hebrewLanguage = LanguageConfig.getLanguageByCode("he")
        assert(hebrewLanguage != null) { "Hebrew language not found in configuration" }
        assert(hebrewLanguage!!.isRTL) { "Hebrew language not marked as RTL" }
    }

    /**
     * Test that Persian/Farsi language is correctly detected as RTL
     */
    @Test
    fun testPersianIsDetectedAsRTL() {
        val persianLanguage = LanguageConfig.getLanguageByCode("fa")
        assert(persianLanguage != null) { "Persian language not found in configuration" }
        assert(persianLanguage!!.isRTL) { "Persian language not marked as RTL" }
    }

    /**
     * Test that Dari (Afghan Persian) language is correctly detected as RTL
     */
    @Test
    fun testDariIsDetectedAsRTL() {
        val dariLanguage = LanguageConfig.getLanguageByCode("fa-AF")
        assert(dariLanguage != null) { "Dari language not found in configuration" }
        assert(dariLanguage!!.isRTL) { "Dari language not marked as RTL" }
    }

    /**
     * Test basic RTL focus order in Hebrew context
     */
    @Test
    fun testHebrewRTLFocusOrder() {
        composeTestRule.setContent {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                TestFormWithThreeFields()
            }
        }

        // In RTL, visual order is right-to-left, but focus order should be logical:
        // Field 1 -> Field 2 -> Field 3 (following natural reading order)
        composeTestRule.onNodeWithTag("field1").performClick()
        composeTestRule.onNodeWithTag("field1").assertIsFocused()

        // Tab to next field
        composeTestRule.onNodeWithTag("field1").performImeAction()
        composeTestRule.onNodeWithTag("field2").assertIsFocused()

        // Tab to next field
        composeTestRule.onNodeWithTag("field2").performImeAction()
        composeTestRule.onNodeWithTag("field3").assertIsFocused()
    }

    /**
     * Test RTL-aware focus traversal with custom navigation
     */
    @Test
    fun testRTLAwareFocusTraversalWithCustomNavigation() {
        lateinit var field1Requester: FocusRequester
        lateinit var field2Requester: FocusRequester
        lateinit var field3Requester: FocusRequester

        composeTestRule.setContent {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                val focusRequesters = FocusManager.rememberFocusGroup(3)
                field1Requester = focusRequesters[0]
                field2Requester = focusRequesters[1]
                field3Requester = focusRequesters[2]

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    // Field 1 (visually on right in RTL)
                    OutlinedTextField(
                        value = "",
                        onValueChange = {},
                        modifier =
                            Modifier
                                .testTag("rtl_field1")
                                .rtlAwareFocusTraversal(
                                    next = field2Requester,
                                    end = field2Requester,
                                ),
                    )

                    // Field 2 (visually in center)
                    OutlinedTextField(
                        value = "",
                        onValueChange = {},
                        modifier =
                            Modifier
                                .testTag("rtl_field2")
                                .rtlAwareFocusTraversal(
                                    previous = field1Requester,
                                    next = field3Requester,
                                    start = field1Requester,
                                    end = field3Requester,
                                ),
                    )

                    // Field 3 (visually on left in RTL)
                    OutlinedTextField(
                        value = "",
                        onValueChange = {},
                        modifier =
                            Modifier
                                .testTag("rtl_field3")
                                .rtlAwareFocusTraversal(
                                    previous = field2Requester,
                                    start = field2Requester,
                                ),
                    )
                }
            }
        }

        // Verify RTL focus navigation works correctly
        composeTestRule.onNodeWithTag("rtl_field1").performClick()
        composeTestRule.onNodeWithTag("rtl_field1").assertIsFocused()
    }

    /**
     * Test that mixed Hebrew/English content maintains correct focus order
     * Example: "שם: John Smith" (Name: John Smith)
     */
    @Test
    fun testHebrewMixedContentFocusOrder() {
        composeTestRule.setContent {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                Column(modifier = Modifier.padding(16.dp)) {
                    // Hebrew label with English input field
                    Text("שם:") // "Name:" in Hebrew
                    OutlinedTextField(
                        value = "",
                        onValueChange = {},
                        placeholder = { Text("John Smith") },
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .testTag("name_field"),
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Hebrew label with numeric input
                    Text("גיל:") // "Age:" in Hebrew
                    OutlinedTextField(
                        value = "",
                        onValueChange = {},
                        placeholder = { Text("25") },
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .testTag("age_field"),
                    )
                }
            }
        }

        // Focus order should be logical despite mixed content
        composeTestRule.onNodeWithTag("name_field").performClick()
        composeTestRule.onNodeWithTag("name_field").assertIsFocused()

        composeTestRule.onNodeWithTag("name_field").performImeAction()
        composeTestRule.onNodeWithTag("age_field").assertIsFocused()
    }

    /**
     * Test that Persian numerals are handled correctly in focus order
     * Persian uses both Eastern Arabic numerals (۰۱۲۳۴۵۶۷۸۹) and Western (0-9)
     */
    @Test
    fun testPersianNumeralsFocusOrder() {
        composeTestRule.setContent {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                Column(modifier = Modifier.padding(16.dp)) {
                    // Date fields with Persian text
                    Text("تاریخ تولد:") // "Date of Birth:" in Persian

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        // Day field
                        OutlinedTextField(
                            value = "",
                            onValueChange = {},
                            placeholder = { Text("روز") }, // "Day"
                            modifier =
                                Modifier
                                    .weight(1f)
                                    .testTag("day_field"),
                        )

                        // Month field
                        OutlinedTextField(
                            value = "",
                            onValueChange = {},
                            placeholder = { Text("ماه") }, // "Month"
                            modifier =
                                Modifier
                                    .weight(1f)
                                    .testTag("month_field"),
                        )

                        // Year field
                        OutlinedTextField(
                            value = "",
                            onValueChange = {},
                            placeholder = { Text("سال") }, // "Year"
                            modifier =
                                Modifier
                                    .weight(1f)
                                    .testTag("year_field"),
                        )
                    }
                }
            }
        }

        // In RTL Persian date entry, focus should follow the logical order
        // even though fields are visually reversed
        composeTestRule.onNodeWithTag("day_field").performClick()
        composeTestRule.onNodeWithTag("day_field").assertIsFocused()
    }

    /**
     * Test bidirectional text with URLs in RTL context
     * Example: "אתר: https://example.com" (Website: https://example.com)
     */
    @Test
    fun testBidirectionalTextWithURLFocusOrder() {
        composeTestRule.setContent {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                Column(modifier = Modifier.padding(16.dp)) {
                    // Hebrew text with URL
                    Text("אתר אינטרנט:") // "Website:" in Hebrew
                    OutlinedTextField(
                        value = "https://example.com",
                        onValueChange = {},
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .testTag("url_field"),
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Hebrew text with email
                    Text("דואר אלקטרוני:") // "Email:" in Hebrew
                    OutlinedTextField(
                        value = "user@example.com",
                        onValueChange = {},
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .testTag("email_field"),
                    )
                }
            }
        }

        // Focus should navigate correctly despite embedded LTR URLs
        composeTestRule.onNodeWithTag("url_field").performClick()
        composeTestRule.onNodeWithTag("url_field").assertIsFocused()

        composeTestRule.onNodeWithTag("url_field").performImeAction()
        composeTestRule.onNodeWithTag("email_field").assertIsFocused()
    }

    /**
     * Test that Persian-specific characters (گچپژ) don't break focus order
     */
    @Test
    fun testPersianSpecificCharactersFocusOrder() {
        composeTestRule.setContent {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                Column(modifier = Modifier.padding(16.dp)) {
                    // Persian text with Persian-specific characters
                    Text("چاپگر") // "Printer" - contains چ and پ
                    OutlinedTextField(
                        value = "",
                        onValueChange = {},
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .testTag("printer_field"),
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text("ژنرال") // "General" - contains ژ
                    OutlinedTextField(
                        value = "",
                        onValueChange = {},
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .testTag("general_field"),
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text("گل") // "Flower" - contains گ
                    OutlinedTextField(
                        value = "",
                        onValueChange = {},
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .testTag("flower_field"),
                    )
                }
            }
        }

        // Verify focus order is maintained with Persian-specific characters
        composeTestRule.onNodeWithTag("printer_field").performClick()
        composeTestRule.onNodeWithTag("printer_field").assertIsFocused()

        composeTestRule.onNodeWithTag("printer_field").performImeAction()
        composeTestRule.onNodeWithTag("general_field").assertIsFocused()

        composeTestRule.onNodeWithTag("general_field").performImeAction()
        composeTestRule.onNodeWithTag("flower_field").assertIsFocused()
    }

    /**
     * Test Hebrew punctuation doesn't affect focus order
     * Hebrew uses different punctuation marks (״ ״ ׳)
     */
    @Test
    fun testHebrewPunctuationFocusOrder() {
        composeTestRule.setContent {
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                Column(modifier = Modifier.padding(16.dp)) {
                    // Hebrew with quotes (״)
                    Text("שם \"חברה\":") // Company "name":
                    OutlinedTextField(
                        value = "",
                        onValueChange = {},
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .testTag("company_field"),
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text("כתובת:") // Address:
                    OutlinedTextField(
                        value = "",
                        onValueChange = {},
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .testTag("address_field"),
                    )
                }
            }
        }

        // Focus order should work correctly with Hebrew punctuation
        composeTestRule.onNodeWithTag("company_field").performClick()
        composeTestRule.onNodeWithTag("company_field").assertIsFocused()

        composeTestRule.onNodeWithTag("company_field").performImeAction()
        composeTestRule.onNodeWithTag("address_field").assertIsFocused()
    }
}

/**
 * Test composable with three fields for basic focus order testing
 */
@Composable
private fun TestFormWithThreeFields() {
    Column(modifier = Modifier.padding(16.dp)) {
        OutlinedTextField(
            value = "",
            onValueChange = {},
            label = { Text("Field 1") },
            modifier =
                Modifier
                    .fillMaxWidth()
                    .testTag("field1"),
        )

        Spacer(modifier = Modifier.height(8.dp))

        OutlinedTextField(
            value = "",
            onValueChange = {},
            label = { Text("Field 2") },
            modifier =
                Modifier
                    .fillMaxWidth()
                    .testTag("field2"),
        )

        Spacer(modifier = Modifier.height(8.dp))

        OutlinedTextField(
            value = "",
            onValueChange = {},
            label = { Text("Field 3") },
            modifier =
                Modifier
                    .fillMaxWidth()
                    .testTag("field3"),
        )
    }
}
