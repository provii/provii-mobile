#!/usr/bin/env python3
"""
Localization Validation Script

This script validates localization files to detect language mix-ups.
Can be run locally or in CI/CD pipelines.

Usage:
    python3 validate_localizations.py
    python3 validate_localizations.py --verbose
    python3 validate_localizations.py --threshold 5
"""

import re
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Tuple
from dataclasses import dataclass

# ANSI color codes
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

# Language indicators
GERMAN_INDICATORS = [
    # Articles
    " der ", " die ", " das ", " den ", " dem ", " des ",
    " ein ", " eine ", " einer ", " einem ", " eines ",
    # Common prepositions and conjunctions
    " und ", " oder ", " aber ", " für ", " mit ", " von ",
    " zu ", " bei ", " nach ", " über ", " unter ",
    # Common verbs
    " ist ", " sind ", " war ", " waren ", " wird ", " werden ",
    " haben ", " hat ", " hatte ", " sein ", " kann ", " könnte ",
    # Common words
    " nicht ", " auch ", " noch ", " mehr ", " sehr ",
    " alle ", " alles ", " einige ", " jeder ", " jede ",
    # Umlauts
    "ä", "ö", "ü", "Ä", "Ö", "Ü", "ß"
]

FRENCH_INDICATORS = [
    # Articles
    " le ", " la ", " les ", " un ", " une ", " des ",
    " du ", " de la ", " au ", " aux ",
    # Common prepositions and conjunctions
    " et ", " ou ", " mais ", " pour ", " avec ", " sans ",
    " dans ", " sur ", " sous ", " chez ", " par ",
    # Common verbs
    " est ", " sont ", " était ", " ont ", " avoir ",
    " être ", " peut ", " pourrait ", " sera ", " serait ",
    # Common words
    " pas ", " plus ", " aussi ", " très ", " tout ",
    " tous ", " toutes ", " quelques ", " chaque ",
    # French-specific characters
    "é", "è", "ê", "ë", "à", "ù", "û", "ï", "î", "ô", "ç", "œ", "æ"
]

# Words that are valid in both German and French. These must be excluded
# from cross-language detection to avoid false positives. "des" is a German
# genitive article and a French partitive article. "du" is German informal
# "you" and a French partitive article.
SHARED_WORDS = {" des ", " du "}

@dataclass
class TestResult:
    name: str
    passed: bool
    message: str = ""

class LocalizationValidator:
    def __init__(self, resources_dir: Path, threshold: int = 3, verbose: bool = False):
        self.resources_dir = resources_dir
        self.threshold = threshold
        self.verbose = verbose
        self.results: List[TestResult] = []

    def parse_strings_file(self, file_path: Path) -> Dict[str, str]:
        """Parse a .strings file and return a dictionary of key-value pairs."""
        translations = {}
        # Match keys and values that may contain escaped quotes (\").
        # The value group uses (?:[^"\\]|\\.)+ to consume either a
        # non-quote-non-backslash character or any backslash escape.
        pattern = r'"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";'

        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        matches = re.finditer(pattern, content)
        for match in matches:
            key, value = match.groups()
            translations[key] = value

        return translations

    def count_indicators(self, text: str, indicators: List[str],
                         exclude: set = None) -> Tuple[int, List[str]]:
        """Count occurrences of indicators in text, skipping any in exclude."""
        text_lower = " " + text.lower() + " "
        found_indicators = []
        total_count = 0
        exclude = exclude or set()

        for indicator in indicators:
            if indicator.lower() in {e.lower() for e in exclude}:
                continue
            count = text_lower.count(indicator.lower())
            if count > 0:
                found_indicators.append(f"{indicator.strip()} ({count}x)")
                total_count += count

        return total_count, found_indicators

    def print_result(self, result: TestResult):
        """Print a test result with color coding."""
        if result.passed:
            symbol = f"{Colors.GREEN}✓{Colors.NC}"
            status = "PASS"
        else:
            symbol = f"{Colors.RED}✗{Colors.NC}"
            status = "FAIL"

        print(f"{symbol} {result.name}")
        if result.message:
            print(f"  {result.message}")

    def test_german_file_no_french(self) -> TestResult:
        """Test that German file doesn't contain French words."""
        de_path = self.resources_dir / "de.lproj" / "Localizable.strings"
        translations = self.parse_strings_file(de_path)

        all_text = " ".join(translations.values())
        count, found = self.count_indicators(all_text, FRENCH_INDICATORS,
                                             exclude=SHARED_WORDS)

        if count < self.threshold:
            return TestResult(
                "German file does not contain French words",
                True,
                f"Found only {count} French indicators (threshold: {self.threshold})"
            )
        else:
            message = f"Found {count} French indicators (threshold: {self.threshold})"
            if self.verbose and found:
                message += f"\n  Indicators: {', '.join(found[:10])}"
            return TestResult(
                "German file does not contain French words",
                False,
                message
            )

    def test_french_file_no_german(self) -> TestResult:
        """Test that French file doesn't contain German words."""
        fr_path = self.resources_dir / "fr.lproj" / "Localizable.strings"
        translations = self.parse_strings_file(fr_path)

        all_text = " ".join(translations.values())
        count, found = self.count_indicators(all_text, GERMAN_INDICATORS,
                                             exclude=SHARED_WORDS)

        if count < self.threshold:
            return TestResult(
                "French file does not contain German words",
                True,
                f"Found only {count} German indicators (threshold: {self.threshold})"
            )
        else:
            message = f"Found {count} German indicators (threshold: {self.threshold})"
            if self.verbose and found:
                message += f"\n  Indicators: {', '.join(found[:10])}"
            return TestResult(
                "French file does not contain German words",
                False,
                message
            )

    def test_german_has_german_characteristics(self) -> TestResult:
        """Test that German file has German language characteristics."""
        de_path = self.resources_dir / "de.lproj" / "Localizable.strings"
        translations = self.parse_strings_file(de_path)

        all_text = " ".join(translations.values())
        count, _ = self.count_indicators(all_text, GERMAN_INDICATORS)

        if count > 50:
            return TestResult(
                "German file has German characteristics",
                True,
                f"Found {count} German indicators"
            )
        else:
            return TestResult(
                "German file has German characteristics",
                False,
                f"Found only {count} German indicators (expected > 50)"
            )

    def test_french_has_french_characteristics(self) -> TestResult:
        """Test that French file has French language characteristics."""
        fr_path = self.resources_dir / "fr.lproj" / "Localizable.strings"
        translations = self.parse_strings_file(fr_path)

        all_text = " ".join(translations.values())
        count, _ = self.count_indicators(all_text, FRENCH_INDICATORS)

        if count > 50:
            return TestResult(
                "French file has French characteristics",
                True,
                f"Found {count} French indicators"
            )
        else:
            return TestResult(
                "French file has French characteristics",
                False,
                f"Found only {count} French indicators (expected > 50)"
            )

    def test_same_keys(self) -> TestResult:
        """Test that both files have the same keys."""
        de_path = self.resources_dir / "de.lproj" / "Localizable.strings"
        fr_path = self.resources_dir / "fr.lproj" / "Localizable.strings"

        de_translations = self.parse_strings_file(de_path)
        fr_translations = self.parse_strings_file(fr_path)

        de_keys = set(de_translations.keys())
        fr_keys = set(fr_translations.keys())

        missing_in_french = de_keys - fr_keys
        missing_in_german = fr_keys - de_keys

        if not missing_in_french and not missing_in_german:
            return TestResult(
                "Both files have the same keys",
                True,
                f"Both files have {len(de_keys)} matching keys"
            )
        else:
            messages = []
            if missing_in_french:
                messages.append(f"Missing in French: {len(missing_in_french)} keys")
                if self.verbose:
                    messages.append(f"  {', '.join(sorted(missing_in_french)[:5])}")
            if missing_in_german:
                messages.append(f"Missing in German: {len(missing_in_german)} keys")
                if self.verbose:
                    messages.append(f"  {', '.join(sorted(missing_in_german)[:5])}")

            return TestResult(
                "Both files have the same keys",
                False,
                "\n  ".join(messages)
            )

    def test_no_empty_translations(self) -> TestResult:
        """Test that there are no empty translations."""
        de_path = self.resources_dir / "de.lproj" / "Localizable.strings"
        fr_path = self.resources_dir / "fr.lproj" / "Localizable.strings"

        de_translations = self.parse_strings_file(de_path)
        fr_translations = self.parse_strings_file(fr_path)

        de_empty = [k for k, v in de_translations.items() if not v.strip()]
        fr_empty = [k for k, v in fr_translations.items() if not v.strip()]

        if not de_empty and not fr_empty:
            return TestResult("No empty translations found", True)
        else:
            messages = []
            if de_empty:
                messages.append(f"German: {len(de_empty)} empty")
                if self.verbose:
                    messages.append(f"  {', '.join(de_empty[:5])}")
            if fr_empty:
                messages.append(f"French: {len(fr_empty)} empty")
                if self.verbose:
                    messages.append(f"  {', '.join(fr_empty[:5])}")

            return TestResult(
                "No empty translations found",
                False,
                "\n  ".join(messages)
            )

    def run_all_tests(self) -> bool:
        """Run all validation tests."""
        print("==================================")
        print("Localization Validation")
        print("==================================")
        print()

        # Run all tests
        self.results = [
            self.test_german_file_no_french(),
            self.test_french_file_no_german(),
            self.test_german_has_german_characteristics(),
            self.test_french_has_french_characteristics(),
            self.test_same_keys(),
            self.test_no_empty_translations(),
        ]

        # Print results
        for result in self.results:
            self.print_result(result)

        # Print summary
        passed = sum(1 for r in self.results if r.passed)
        failed = sum(1 for r in self.results if not r.passed)

        print()
        print("==================================")
        print("Summary")
        print("==================================")
        print(f"Total tests: {len(self.results)}")
        print(f"Passed: {Colors.GREEN}{passed}{Colors.NC}")
        print(f"Failed: {Colors.RED}{failed}{Colors.NC}")
        print()

        if failed > 0:
            print(f"{Colors.RED}Validation failed!{Colors.NC}")
            return False
        else:
            print(f"{Colors.GREEN}All validation tests passed!{Colors.NC}")
            return True

def main():
    parser = argparse.ArgumentParser(description="Validate localization files")
    parser.add_argument(
        "--threshold",
        type=int,
        default=3,
        help="Threshold for language indicator violations (default: 3)"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Show detailed output"
    )
    parser.add_argument(
        "--resources-dir",
        type=Path,
        help="Path to resources directory (auto-detected if not specified)"
    )

    args = parser.parse_args()

    # Auto-detect resources directory
    if args.resources_dir:
        resources_dir = args.resources_dir
    else:
        script_dir = Path(__file__).parent
        resources_dir = script_dir.parent / "ProviiWallet" / "ProviiWallet" / "Resources"

    # Check if resources directory exists
    if not resources_dir.exists():
        print(f"{Colors.RED}Error: Resources directory not found: {resources_dir}{Colors.NC}")
        sys.exit(1)

    # Check if localization files exist
    de_file = resources_dir / "de.lproj" / "Localizable.strings"
    fr_file = resources_dir / "fr.lproj" / "Localizable.strings"

    if not de_file.exists():
        print(f"{Colors.RED}Error: German localization file not found: {de_file}{Colors.NC}")
        sys.exit(1)

    if not fr_file.exists():
        print(f"{Colors.RED}Error: French localization file not found: {fr_file}{Colors.NC}")
        sys.exit(1)

    # Run validation
    validator = LocalizationValidator(
        resources_dir=resources_dir,
        threshold=args.threshold,
        verbose=args.verbose
    )

    success = validator.run_all_tests()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
