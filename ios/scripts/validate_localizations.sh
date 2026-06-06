#!/bin/bash

# Localization Validation Script
# This script validates localization files to detect language mix-ups
# Can be run locally or in CI/CD pipelines

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESOURCES_DIR="$PROJECT_ROOT/ProviiWallet/ProviiWallet/Resources"
FAILURE_THRESHOLD=3

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# German language indicators
GERMAN_INDICATORS=(
    " der " " die " " das " " den " " dem " " des "
    " ein " " eine " " einer " " einem " " eines "
    " und " " oder " " aber " " für " " mit " " von "
    " zu " " bei " " nach " " über " " unter "
    " ist " " sind " " war " " waren " " wird " " werden "
    " haben " " hat " " hatte " " sein " " kann " " könnte "
    " nicht " " auch " " noch " " mehr " " sehr "
    "ä" "ö" "ü" "Ä" "Ö" "Ü" "ß"
)

# French language indicators
FRENCH_INDICATORS=(
    " le " " la " " les " " un " " une " " des "
    " du " " de la " " au " " aux "
    " et " " ou " " mais " " pour " " avec " " sans "
    " dans " " sur " " sous " " chez " " par "
    " est " " sont " " était " " ont " " avoir "
    " être " " peut " " pourrait " " sera " " serait "
    " pas " " plus " " aussi " " très " " tout "
    " tous " " toutes " " quelques " " chaque "
    "é" "è" "ê" "ë" "à" "ù" "û" "ï" "î" "ô" "ç" "œ" "æ"
)

# Helper function to print test results
print_test_result() {
    local test_name=$1
    local result=$2
    local message=$3

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        if [ -n "$message" ]; then
            echo "  $message"
        fi
    else
        echo -e "${RED}✗${NC} $test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        if [ -n "$message" ]; then
            echo "  $message"
        fi
    fi
}

# Function to extract translation values from .strings file
extract_translations() {
    local file=$1
    grep -o '"[^"]*"[[:space:]]*=[[:space:]]*"[^"]*";' "$file" | \
        sed -E 's/"[^"]*"[[:space:]]*=[[:space:]]*"([^"]*)";/\1/' | \
        tr '\n' ' '
}

# Function to count indicators in text
count_indicators() {
    local text=$1
    shift
    local indicators=("$@")
    local count=0

    # Convert text to lowercase and add spaces at beginning and end
    text=" $(echo "$text" | tr '[:upper:]' '[:lower:]') "

    for indicator in "${indicators[@]}"; do
        # Count occurrences
        local occurrences=$(echo "$text" | grep -o "$(echo "$indicator" | tr '[:upper:]' '[:lower:]')" | wc -l)
        count=$((count + occurrences))
    done

    echo "$count"
}

echo "=================================="
echo "Localization Validation"
echo "=================================="
echo ""

# Check if localization files exist
if [ ! -f "$RESOURCES_DIR/de.lproj/Localizable.strings" ]; then
    echo -e "${RED}Error: German localization file not found${NC}"
    exit 1
fi

if [ ! -f "$RESOURCES_DIR/fr.lproj/Localizable.strings" ]; then
    echo -e "${RED}Error: French localization file not found${NC}"
    exit 1
fi

# Test 1: German file should not contain French words
echo "Test 1: Checking German file for French words..."
german_text=$(extract_translations "$RESOURCES_DIR/de.lproj/Localizable.strings")
french_in_german=$(count_indicators "$german_text" "${FRENCH_INDICATORS[@]}")

if [ "$french_in_german" -lt "$FAILURE_THRESHOLD" ]; then
    print_test_result "German file does not contain French words" "PASS" \
        "Found only $french_in_german French indicators (threshold: $FAILURE_THRESHOLD)"
else
    print_test_result "German file does not contain French words" "FAIL" \
        "Found $french_in_german French indicators (threshold: $FAILURE_THRESHOLD)"
fi

# Test 2: French file should not contain German words
echo "Test 2: Checking French file for German words..."
french_text=$(extract_translations "$RESOURCES_DIR/fr.lproj/Localizable.strings")
german_in_french=$(count_indicators "$french_text" "${GERMAN_INDICATORS[@]}")

if [ "$german_in_french" -lt "$FAILURE_THRESHOLD" ]; then
    print_test_result "French file does not contain German words" "PASS" \
        "Found only $german_in_french German indicators (threshold: $FAILURE_THRESHOLD)"
else
    print_test_result "French file does not contain German words" "FAIL" \
        "Found $german_in_french German indicators (threshold: $FAILURE_THRESHOLD)"
fi

# Test 3: German file should have German characteristics
echo "Test 3: Checking German file has German characteristics..."
german_indicators_in_german=$(count_indicators "$german_text" "${GERMAN_INDICATORS[@]}")

if [ "$german_indicators_in_german" -gt 50 ]; then
    print_test_result "German file has German characteristics" "PASS" \
        "Found $german_indicators_in_german German indicators"
else
    print_test_result "German file has German characteristics" "FAIL" \
        "Found only $german_indicators_in_german German indicators (expected > 50)"
fi

# Test 4: French file should have French characteristics
echo "Test 4: Checking French file has French characteristics..."
french_indicators_in_french=$(count_indicators "$french_text" "${FRENCH_INDICATORS[@]}")

if [ "$french_indicators_in_french" -gt 50 ]; then
    print_test_result "French file has French characteristics" "PASS" \
        "Found $french_indicators_in_french French indicators"
else
    print_test_result "French file has French characteristics" "FAIL" \
        "Found only $french_indicators_in_french French indicators (expected > 50)"
fi

# Test 5: Both files should have the same number of translations
echo "Test 5: Checking both files have same number of translations..."
german_count=$(grep -c '"[^"]*"[[:space:]]*=[[:space:]]*"[^"]*";' "$RESOURCES_DIR/de.lproj/Localizable.strings" || true)
french_count=$(grep -c '"[^"]*"[[:space:]]*=[[:space:]]*"[^"]*";' "$RESOURCES_DIR/fr.lproj/Localizable.strings" || true)

if [ "$german_count" -eq "$french_count" ]; then
    print_test_result "Both files have same number of translations" "PASS" \
        "Both files have $german_count translations"
else
    print_test_result "Both files have same number of translations" "FAIL" \
        "German: $german_count, French: $french_count"
fi

# Test 6: Check for empty translations
echo "Test 6: Checking for empty translations..."
german_empty=$(grep '"[^"]*"[[:space:]]*=[[:space:]]*"";' "$RESOURCES_DIR/de.lproj/Localizable.strings" | wc -l)
french_empty=$(grep '"[^"]*"[[:space:]]*=[[:space:]]*"";' "$RESOURCES_DIR/fr.lproj/Localizable.strings" | wc -l)

if [ "$german_empty" -eq 0 ] && [ "$french_empty" -eq 0 ]; then
    print_test_result "No empty translations found" "PASS"
else
    print_test_result "No empty translations found" "FAIL" \
        "German: $german_empty empty, French: $french_empty empty"
fi

# Print summary
echo ""
echo "=================================="
echo "Summary"
echo "=================================="
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo ""

# Exit with error if any tests failed
if [ "$FAILED_TESTS" -gt 0 ]; then
    echo -e "${RED}Validation failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All validation tests passed!${NC}"
    exit 0
fi
