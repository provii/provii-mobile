# Localization Validation Scripts

This directory contains scripts for validating localization files to prevent translation mix-ups and ensure quality.

## Available Scripts

### `validate_localizations.py` (Recommended)

Python script for comprehensive localization validation. Works on all platforms.

**Usage:**
```bash
# Basic validation
python3 validate_localizations.py

# Verbose mode (shows which indicators were found)
python3 validate_localizations.py --verbose

# Custom threshold
python3 validate_localizations.py --threshold 5

# Help
python3 validate_localizations.py --help
```

**Features:**
- Cross-platform (macOS, Linux, Windows)
- Detailed error reporting
- Configurable thresholds
- Colored output
- Fast execution

### `validate_localizations.sh`

Bash script for quick validation. macOS/Linux only.

**Usage:**
```bash
./validate_localizations.sh
```

**Features:**
- No dependencies (just bash)
- Fast execution
- Color-coded output
- Perfect for git hooks

## What Gets Validated

### Language Mix-up Detection

1. **German file doesn't contain French words**
   - Scans for French articles (le, la, les, etc.)
   - Checks for French verbs (est, sont, etc.)
   - Detects French accented characters (é, è, à, etc.)

2. **French file doesn't contain German words**
   - Scans for German articles (der, die, das, etc.)
   - Checks for German verbs (ist, sind, etc.)
   - Detects German umlauts (ä, ö, ü, ß, etc.)

### Language Characteristic Validation

3. **German file has German characteristics**
   - Verifies presence of German language patterns
   - Ensures file is actually in German

4. **French file has French characteristics**
   - Verifies presence of French language patterns
   - Ensures file is actually in French

### Quality Checks

5. **Same keys in both files**
   - Ensures all translations exist in both languages
   - Detects missing translations

6. **No empty translations**
   - Checks for empty string values
   - Prevents shipping incomplete translations

## Integration Examples

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
./ios/scripts/validate_localizations.sh
if [ $? -ne 0 ]; then
    echo "Localization validation failed. Commit aborted."
    exit 1
fi
```

Then make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

### GitHub Actions

See `.github/workflows/validate-localizations.yml` for the complete workflow.

Quick example:
```yaml
- name: Validate localizations
  run: python3 ios/scripts/validate_localizations.py
```

### Fastlane

Add to your `Fastfile`:

```ruby
lane :validate_localizations do
  sh("python3 ../ios/scripts/validate_localizations.py")
end

before_all do
  validate_localizations
end
```

### Xcode Build Phase

1. In Xcode, select your target
2. Go to Build Phases
3. Add a "Run Script" phase
4. Add this script:

```bash
"${SRCROOT}/scripts/validate_localizations.sh"
```

## Troubleshooting

### Tests Pass But I See Issues

The threshold might be too high. Lower it for stricter validation:

```bash
python3 validate_localizations.py --threshold 2
```

### Too Many False Positives

Some words appear in multiple languages. Increase the threshold:

```bash
python3 validate_localizations.py --threshold 5
```

### Script Can't Find Files

Specify the resources directory explicitly:

```bash
python3 validate_localizations.py --resources-dir /path/to/Resources
```

## Adding New Languages

To add validation for other language pairs:

1. Define language indicators in the script
2. Add new test functions
3. Update the main validation loop

Example:
```python
SPANISH_INDICATORS = [" el ", " la ", " los ", " las ", " es ", " son ", ...]
ITALIAN_INDICATORS = [" il ", " la ", " gli ", " le ", " è ", " sono ", ...]

def test_spanish_no_italian():
    # Implementation
    pass
```

## Testing the Validator

To verify the validator works, temporarily add wrong-language words:

1. Edit `de.lproj/Localizable.strings`
2. Add French words: `"test" = "avec le problème";`
3. Run validator - should fail
4. Remove the test change

## Performance

Both scripts are designed for speed:
- Python script: ~0.5 seconds
- Bash script: ~0.3 seconds

Even with thousands of translations, validation is nearly instant.

## Exit Codes

- `0`: All validations passed
- `1`: One or more validations failed

This makes it easy to integrate into CI/CD pipelines.

## Support

For issues or questions:
1. Check the main documentation: `PHASE6_VALIDATION_TESTS.md`
2. Review test output for specific error messages
3. Run with `--verbose` flag for detailed diagnostics

## Related Files

- Swift tests: `../ProviiWalletTests/LocalizationValidationTests.swift`
- Documentation: `../../PHASE6_VALIDATION_TESTS.md`
- CI workflow: `../../.github/workflows/validate-localizations.yml`
