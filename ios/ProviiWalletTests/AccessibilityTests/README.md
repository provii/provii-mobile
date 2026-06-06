# iOS Accessibility Test Suite

Comprehensive accessibility testing suite for Provii Wallet iOS app using XCUITest.

## Overview

This test suite validates that the Provii Wallet iOS app meets accessibility standards including:

- VoiceOver compatibility
- Dynamic Type support
- Color contrast requirements (WCAG AA/AAA)
- Touch target sizes
- Accessibility labels and hints

## Test Files

### VoiceOverTests.swift
Tests VoiceOver screen reader compatibility:
- Accessibility labels for all interactive elements
- Navigation flow and focus order
- Touch target sizes
- Custom actions
- Error announcements
- Dynamic content updates

### DynamicTypeTests.swift
Tests Dynamic Type (text scaling) support:
- All accessibility text sizes (up to 3x larger)
- Layout adaptation
- No text truncation
- Component responsiveness (navigation, tabs, forms, lists, cards, modals)

### ColorContrastTests.swift
Tests color contrast compliance:
- WCAG AA compliance (4.5:1 for text, 3:1 for large text/UI)
- WCAG AAA compliance (7:1 for text, 4.5:1 for large text)
- Dark mode contrast
- Increased Contrast mode support
- Color blindness considerations

### AccessibilityTestHelpers.swift
Utility functions and extensions:
- Touch target size verification
- Accessibility label verification
- Element visibility checks
- Screenshot helpers
- Navigation helpers
- Launch configuration helpers

## Running Tests

### Using Xcode

1. Open `ProviiWallet.xcodeproj` or `ProviiWallet.xcworkspace`
2. Select the `ProviiWalletTests` scheme
3. Navigate to Test Navigator (⌘6)
4. Expand `AccessibilityTests` folder
5. Run all tests: Click the play button next to `AccessibilityTests`
6. Run specific test file: Click play button next to specific file
7. Run individual test: Click play button next to specific test method

### Using Command Line

Run all accessibility tests:
```bash
cd /Users/timoconnor/Provii/provii-mobile/ios
xcodebuild test \
  -workspace ProviiWallet.xcworkspace \
  -scheme ProviiWallet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ProviiWalletTests/VoiceOverTests \
  -only-testing:ProviiWalletTests/DynamicTypeTests \
  -only-testing:ProviiWalletTests/ColorContrastTests
```

Run specific test class:
```bash
xcodebuild test \
  -workspace ProviiWallet.xcworkspace \
  -scheme ProviiWallet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ProviiWalletTests/VoiceOverTests
```

Run specific test method:
```bash
xcodebuild test \
  -workspace ProviiWallet.xcworkspace \
  -scheme ProviiWallet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ProviiWalletTests/VoiceOverTests/testAllButtonsHaveAccessibilityLabels
```

### CI/CD Integration

Add to your GitHub Actions or CI pipeline:

```yaml
- name: Run Accessibility Tests
  run: |
    xcodebuild test \
      -workspace ProviiWallet.xcworkspace \
      -scheme ProviiWallet \
      -destination 'platform=iOS Simulator,name=iPhone 15' \
      -only-testing:ProviiWalletTests/VoiceOverTests \
      -only-testing:ProviiWalletTests/DynamicTypeTests \
      -only-testing:ProviiWalletTests/ColorContrastTests \
      -resultBundlePath TestResults/AccessibilityTests.xcresult
```

## Test Requirements

### Minimum iOS Version
- iOS 14.0+ (for full XCUITest accessibility features)

### Recommended Simulators
- iPhone 15 (latest hardware)
- iPhone SE (3rd gen) (smaller screen)
- iPad Pro 12.9" (larger screen)

### Device Settings to Test
The tests automatically configure these settings, but manual testing should also verify:
- VoiceOver ON
- Dynamic Type: All sizes from Small to Accessibility Extra Extra Extra Large
- Increased Contrast: ON
- Reduce Transparency: ON
- Reduce Motion: ON
- Dark Mode / Light Mode

## Accessibility Standards

This test suite validates compliance with:

### Apple Human Interface Guidelines
- [Accessibility - HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- Minimum touch target: 44x44 points
- VoiceOver compatibility
- Dynamic Type support

### WCAG 2.1 Guidelines
- **Level AA** (minimum):
  - 4.5:1 contrast for normal text
  - 3:1 contrast for large text (18pt+) and UI components
- **Level AAA** (recommended):
  - 7:1 contrast for normal text
  - 4.5:1 contrast for large text

## Common Issues and Fixes

### Missing Accessibility Labels
**Issue**: Buttons or images missing labels
**Fix**: Add `.accessibilityLabel("descriptive label")` modifier

### Text Truncation with Dynamic Type
**Issue**: Text cuts off at large sizes
**Fix**:
- Use `lineLimit(nil)` or appropriate limit
- Set `adjustsFontForContentSizeCategory = true`
- Use adaptive layouts (Stack, ScrollView)

### Small Touch Targets
**Issue**: Touch targets smaller than 44x44 points
**Fix**: Add `.frame(minWidth: 44, minHeight: 44)` or padding

### Poor Contrast
**Issue**: Text/UI elements don't meet contrast requirements
**Fix**: Use semantic colors from design system, test in both light/dark modes

## Manual Testing Checklist

While automated tests cover many scenarios, manual testing is still important:

- [ ] Navigate entire app with VoiceOver enabled
- [ ] Test all text sizes from Settings > Accessibility > Display & Text Size
- [ ] Test with Increased Contrast enabled
- [ ] Test with Reduce Motion enabled
- [ ] Test with Reduce Transparency enabled
- [ ] Verify color blindness accessibility (use Color Filters in Settings)
- [ ] Test with external keyboard navigation
- [ ] Test with Switch Control
- [ ] Test with Voice Control

## Resources

### Apple Documentation
- [UIAccessibility](https://developer.apple.com/documentation/uikit/accessibility_for_uikit)
- [XCUITest](https://developer.apple.com/documentation/xctest)
- [Accessibility Programming Guide](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/iPhoneAccessibility/Introduction/Introduction.html)

### Testing Tools
- **Accessibility Inspector** (Xcode → Xcode → Open Developer Tool → Accessibility Inspector)
- **VoiceOver** (Settings → Accessibility → VoiceOver)
- **Color Contrast Analyzer** (third-party tools for detailed analysis)

### WCAG Resources
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)

## Contributing

When adding new features or screens to the app:

1. Add corresponding accessibility tests
2. Verify VoiceOver labels and navigation
3. Test with largest Dynamic Type size
4. Verify color contrast in both light and dark modes
5. Run full accessibility test suite before submitting PR

## Questions or Issues?

For questions about accessibility testing or to report issues with these tests, please contact the development team or file an issue in the repository.
