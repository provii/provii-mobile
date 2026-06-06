# Android Accessibility Test Suite

Comprehensive accessibility testing suite for Provii Wallet Android app using Jetpack Compose UI Testing and Espresso.

## Overview

This test suite validates that the Provii Wallet Android app meets accessibility standards including:

- TalkBack screen reader compatibility
- Font scaling support
- Content descriptions for all interactive elements
- Proper heading hierarchy
- Touch target sizes
- Semantic properties

## Test Files

### ContentDescriptionTest.kt
Tests that all UI elements have appropriate content descriptions:
- Icons and images have descriptions
- Buttons have meaningful labels
- Text fields have proper labels
- Decorative elements are marked as decorative
- State changes are announced

### TalkBackNavigationTest.kt
Tests TalkBack screen reader navigation:
- Logical navigation order
- Heading navigation and hierarchy
- Focus management
- Custom actions for gestures
- List navigation
- Form accessibility
- Live region announcements
- Dynamic content updates

### FontScalingTest.kt
Tests font scaling and text size support:
- Support for 200% font size
- Layout adaptation
- No text truncation
- Component responsiveness (buttons, text fields, lists, cards, dialogs)
- Minimum touch target maintenance

### HeadingHierarchyTest.kt
Tests semantic heading structure:
- Each screen has H1 heading
- Logical heading hierarchy
- Section headings (H2, H3)
- No skipped heading levels
- Consistent heading usage

### AccessibilityTestHelpers.kt
Utility functions and extensions:
- Content description assertions
- Heading assertions
- Touch target size verification
- Role assertions (Button, Checkbox, Image, etc.)
- State assertions
- Semantic matchers
- Color contrast calculation helpers

## Running Tests

### Using Android Studio

1. Open project in Android Studio
2. Navigate to `/android/app/src/androidTest/java/com/provii/wallet/accessibility/`
3. Right-click on `accessibility` folder → Run Tests
4. Or right-click individual test file → Run
5. Or click the green play button next to a test class/method

### Using Command Line

Run all accessibility tests:
```bash
cd /Users/timoconnor/Provii/provii-mobile/android

# Using Gradle wrapper
./gradlew connectedAndroidTest -Pandroid.testInstrumentationRunnerArguments.package=app.provii.wallet.accessibility
```

Run specific test class:
```bash
./gradlew connectedAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=app.provii.wallet.accessibility.ContentDescriptionTest
```

Run specific test method:
```bash
./gradlew connectedAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=app.provii.wallet.accessibility.ContentDescriptionTest#allIconsHaveContentDescription
```

### Using ADB

Run tests on connected device:
```bash
adb shell am instrument -w -r \
  -e class app.provii.wallet.accessibility.ContentDescriptionTest \
  app.provii.wallet.test/androidx.test.runner.AndroidJUnitRunner
```

### CI/CD Integration

Add to your GitHub Actions or CI pipeline:

```yaml
- name: Run Accessibility Tests
  run: |
    cd android
    ./gradlew connectedAndroidTest \
      -Pandroid.testInstrumentationRunnerArguments.package=app.provii.wallet.accessibility

- name: Upload Test Reports
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: accessibility-test-results
    path: android/app/build/reports/androidTests/connected/
```

## Test Requirements

### Minimum Android Version
- Android API 21+ (Lollipop 5.0)
- Recommended: API 26+ for full semantics support

### Dependencies

Ensure these are in your `build.gradle`:

```gradle
androidTestImplementation "androidx.compose.ui:ui-test-junit4:$compose_version"
androidTestImplementation "androidx.test.ext:junit:1.1.5"
androidTestImplementation "androidx.test:runner:1.5.2"
androidTestImplementation "androidx.test:rules:1.5.0"
debugImplementation "androidx.compose.ui:ui-test-manifest:$compose_version"
```

### Test Devices
Recommended test configurations:
- Pixel 6 (large screen, modern Android)
- Pixel 4a (mid-size screen)
- Samsung Galaxy S10 (different manufacturer)
- Android Emulator API 30+

## Accessibility Standards

This test suite validates compliance with:

### Android Accessibility Guidelines
- [Android Accessibility Help](https://developer.android.com/guide/topics/ui/accessibility)
- Minimum touch target: 48x48 dp
- TalkBack compatibility
- Font scaling support (up to 200%)
- Material Design accessibility guidelines

### WCAG 2.1 Guidelines
- **Level AA** (minimum):
  - 4.5:1 contrast for normal text
  - 3:1 contrast for large text (18pt+) and UI components
  - 48dp minimum touch target
- **Level AAA** (recommended):
  - 7:1 contrast for normal text
  - 4.5:1 contrast for large text

## Common Issues and Fixes

### Missing Content Descriptions
**Issue**: Images or buttons missing contentDescription
**Fix**: Add to Composable:
```kotlin
Modifier.semantics {
    contentDescription = "Descriptive label"
}
```

### No Heading Hierarchy
**Issue**: Screens don't have proper heading structure
**Fix**: Mark headings:
```kotlin
Text(
    text = "Screen Title",
    modifier = Modifier.semantics { heading() }
)
```

### Text Truncation with Large Fonts
**Issue**: Text cuts off at large font sizes
**Fix**:
```kotlin
Text(
    text = "...",
    maxLines = Int.MAX_VALUE,  // Or appropriate value
    overflow = TextOverflow.Visible
)
```

### Small Touch Targets
**Issue**: Touch targets smaller than 48dp
**Fix**:
```kotlin
IconButton(
    onClick = { },
    modifier = Modifier.size(48.dp)  // Minimum size
) { ... }
```

### Dynamic Content Not Announced
**Issue**: Updates aren't announced to TalkBack
**Fix**:
```kotlin
Text(
    text = statusMessage,
    modifier = Modifier.semantics {
        liveRegion = LiveRegionMode.Polite  // Or Assertive for urgent
    }
)
```

## Test Implementation Guide

### Adding Tests for New Features

When adding new screens or components:

1. **Add Content Description Tests**
   - Verify all interactive elements have descriptions
   - Check decorative elements are marked appropriately

2. **Add Navigation Tests**
   - Test TalkBack navigation flow
   - Verify focus management
   - Add custom actions for gestures

3. **Add Font Scaling Tests**
   - Test component at 200% font size
   - Verify layouts adapt
   - Check for text truncation

4. **Add Heading Tests**
   - Ensure screen has H1 heading
   - Verify section headings
   - Check hierarchy

### Example Test Implementation

```kotlin
@Test
fun testNewFeatureAccessibility() {
    // Navigate to your feature
    composeTestRule.onNodeWithText("My Feature").performClick()

    // Verify heading
    composeTestRule.onNode(isHeading() and hasText("Feature Title"))
        .assertExists()

    // Verify content descriptions
    composeTestRule.onNodeWithTag("feature_action_button")
        .assertHasContentDescription()

    // Verify touch target
    composeTestRule.onNodeWithTag("feature_action_button")
        .assertMinimumTouchTarget()

    // Test navigation order
    composeTestRule.onRoot().printToLog("FEATURE_TREE")
}
```

## Manual Testing Checklist

While automated tests cover many scenarios, manual testing is essential:

### TalkBack Testing
- [ ] Enable TalkBack: Settings → Accessibility → TalkBack
- [ ] Navigate through entire app using swipe gestures
- [ ] Test all interactive elements activate on double-tap
- [ ] Verify custom actions appear in TalkBack menu
- [ ] Test form submission and error handling
- [ ] Verify dynamic content is announced

### Font Scaling Testing
- [ ] Settings → Display → Font size → Largest
- [ ] Settings → Display → Display size → Largest
- [ ] Navigate through all screens
- [ ] Verify no text truncation
- [ ] Verify all buttons remain tappable
- [ ] Verify layouts adapt appropriately

### Additional Settings
- [ ] High contrast text
- [ ] Color correction (for color blindness)
- [ ] Color inversion
- [ ] Remove animations
- [ ] Switch Access

## Accessibility Scanner Integration

Use Google's Accessibility Scanner for additional validation:

1. Install Accessibility Scanner from Play Store
2. Enable the service in Settings
3. Open Provii Wallet
4. Tap the Accessibility Scanner button
5. Review suggestions and fix issues
6. Re-run automated tests to verify fixes

## Tools and Resources

### Android Tools
- **Accessibility Scanner** - Automated scanning tool
- **TalkBack** - Built-in screen reader
- **Switch Access** - Navigate using switches
- **Layout Inspector** - View accessibility properties in Android Studio

### Testing Tools
- **Compose UI Testing** - [Documentation](https://developer.android.com/jetpack/compose/testing)
- **Espresso** - [Testing Framework](https://developer.android.com/training/testing/espresso)
- **Accessibility Test Framework** - [Google's testing library](https://github.com/google/Accessibility-Test-Framework-for-Android)

### Resources
- [Android Accessibility Guide](https://developer.android.com/guide/topics/ui/accessibility)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)

## Contributing

When adding new features or screens:

1. Add corresponding accessibility tests to all test classes
2. Verify TalkBack navigation and announcements
3. Test with largest font size (200%)
4. Verify color contrast in light and dark themes
5. Add semantic properties (contentDescription, heading, role)
6. Run full accessibility test suite before submitting PR
7. Use Accessibility Scanner to catch additional issues

## Debugging Tests

### Common Issues

**Tests fail due to timing:**
- Use `waitUntil()` helper for dynamic content
- Add appropriate delays for animations
- Use `composeTestRule.waitForIdle()`

**Can't find nodes:**
- Use `onRoot().printToLog()` to see semantics tree
- Verify test tags are set: `Modifier.testTag("my_tag")`
- Check semantics properties are correctly set

**Font scaling tests don't work:**
- Font scaling must be set before activity launch
- May need custom test rule to set configuration
- Consider using separate instrumentation runs for different scales

## Questions or Issues?

For questions about accessibility testing or to report issues with these tests, please contact the development team or file an issue in the repository.

---

**Remember**: Accessibility is not just about passing tests - it's about creating an app that everyone can use effectively. Manual testing with actual assistive technologies is crucial!
