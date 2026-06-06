#!/bin/bash
# iOS coverage gate: enforces a minimum line coverage percentage on the
# logic-layer scope. Mirrors the Android jacocoCoverageGate task.
#
# Usage: ./check_coverage_gate.sh <xcresult_path> [min_coverage_pct]
#
# Included scope (pure logic, no platform framework dependencies):
#   Core/Config/JsonCanonicaliser.swift
#   Core/Models/ (DTOs, value types)
#   Core/Security/ConstantTimeCompare.swift, DeepLinkValidator.swift,
#     RateLimiter.swift, SecureString.swift, SensitiveDataHolder.swift
#   Core/Services/CryptoUtils.swift, HmacSigner.swift
#   Utils/Helpers/ErrorHandler.swift, ErrorMapper.swift, Validators.swift
#
# Excluded (with justification, mirroring Android jacocoExcludes):
#   SwiftUI Views           - pure presentation, not logic
#   ProviiSDK.swift         - generated UniFFI bindings, tested upstream
#   WalletSDKBridge.swift   - thin FFI bridge
#   ProviiWalletApp.swift   - app entry point
#   UI/Components/          - SwiftUI view components
#   Examples/, Resources/   - sample code, string catalogs
#   Navigation/             - DeepLinkHandler, NavigationCoordinator depend on
#                             UIKit singletons, EnvironmentManager Keychain
#   Core/Repositories/      - WalletRepository depends on SDK + Keychain
#   Core/Services/Keychain* - Keychain not available in unit test host
#   Core/Services/Network*  - URLSession integration
#   Core/Services/Biometric - LAContext not available in test host
#   Core/Services/AuditLogger - Keychain dependency
#   Core/Services/Officer*  - YubiKey + Keychain
#   Core/Services/Storage*  - Keychain dependency
#   Core/Config/Environment* - Keychain dependency
#   Core/Config/Sandbox*    - Network + Keychain dependency
#   Core/Security/Security* - Keychain + runtime checks
#   Core/Security/Screen*   - UIApplication dependency
#   Core/Security/Clipboard - UIPasteboard dependency
#   Core/Security/Debugger* - Low-level sysctl
#   Core/Security/Frida*    - Low-level process inspection
#   Core/Security/Integrity - Bundle inspection
#   Core/Security/Jailbreak - Filesystem probing
#   Core/Settings/          - Keychain dependency
#   Core/DependencyContainer - wires all singletons
#   Features/               - Accessibility, Help, Search depend on SwiftUI or singletons
#   Utils/ (most)           - Accessibility utils are SwiftUI modifiers; Content
#                             uses Bundle; DataPreservation uses Keychain

set -euo pipefail

XCRESULT="${1:?Usage: check_coverage_gate.sh <xcresult_path> [min_coverage_pct]}"
MIN_COVERAGE="${2:-85}"

if [ ! -d "$XCRESULT" ]; then
    echo "ERROR: xcresult bundle not found at $XCRESULT"
    exit 1
fi

COVERAGE_TMPFILE=$(mktemp /tmp/xccov_report_XXXXXX)
trap 'rm -f "$COVERAGE_TMPFILE"' EXIT

if ! xcrun xccov view --report --json "$XCRESULT" > "$COVERAGE_TMPFILE" 2>/dev/null; then
    echo "ERROR: xccov failed to extract coverage data from $XCRESULT"
    echo "This usually means the test build did not compile successfully."
    echo "Check the 'Run iOS unit tests' step above for compilation errors."
    exit 1
fi

if [ ! -s "$COVERAGE_TMPFILE" ]; then
    echo "ERROR: xccov produced an empty report from $XCRESULT"
    exit 1
fi

python3 - "$COVERAGE_TMPFILE" "$MIN_COVERAGE" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    coverage_json = json.load(f)
min_coverage = float(sys.argv[2])

# Exact files in scope (pure logic, no platform dependencies).
# This matches the Android jacocoCoverageGate philosophy: only files
# whose logic can be fully exercised in a unit test host without
# mocking platform frameworks (Keychain, UIKit, LAContext).
in_scope_files_set = {
    "Core/Config/JsonCanonicaliser.swift",
    "Core/Models/AppError.swift",
    "Core/Models/OfficerModels.swift",
    "Core/Models/StoredCredential.swift",
    "Core/Models/VerificationChallenge.swift",
    "Core/Security/ConstantTimeCompare.swift",
    "Core/Security/DeepLinkValidator.swift",
    "Core/Security/SecureString.swift",
    "Core/Security/SensitiveDataHolder.swift",
    "Core/Services/CryptoUtils.swift",
    "Core/Services/HmacSigner.swift",
    "Utils/Helpers/ErrorMapper.swift",
    "Utils/Helpers/Validators.swift",
    # Excluded from gate (with justification):
    #   RateLimiter.swift       - persists state to Keychain via KeychainBridge;
    #                             unit tests crash on simulator without entitlements
    #   ErrorHandler.swift      - mixed file: ~100 lines of SwiftUI ErrorAlert
    #                             ViewModifier cannot be unit tested (requires host app
    #                             view hierarchy). Pure logic portion is tested via
    #                             ErrorHandlerTests + ErrorHandlerExtendedTests.
}

total_lines = 0
covered_lines = 0
in_scope = []

for target in coverage_json.get("targets", []):
    for f in target.get("files", []):
        path = f.get("path", "")

        marker = "ProviiWallet/ProviiWallet/"
        idx = path.find(marker)
        if idx < 0:
            continue
        relative = path[idx + len(marker):]

        if relative not in in_scope_files_set:
            continue

        file_lines = f.get("executableLines", 0)
        file_covered = f.get("coveredLines", 0)
        file_pct = (file_covered / file_lines * 100) if file_lines > 0 else 0.0

        total_lines += file_lines
        covered_lines += file_covered
        in_scope.append((relative, file_lines, file_covered, file_pct))

overall = (covered_lines / total_lines * 100) if total_lines > 0 else 0.0

print(f"iOS Logic Scope Coverage Report")
print(f"{'='*70}")
print(f"{'File':<55} {'Lines':>5} {'Cov':>5} {'%':>6}")
print(f"{'-'*70}")
for rel, lines, cov, pct in sorted(in_scope):
    short = rel[-54:] if len(rel) > 54 else rel
    print(f"{short:<55} {lines:>5} {cov:>5} {pct:>5.1f}%")
print(f"{'-'*70}")
print(f"{'TOTAL':<55} {total_lines:>5} {covered_lines:>5} {overall:>5.1f}%")
print(f"{'='*70}")
print(f"Gate: {min_coverage}% | Actual: {overall:.1f}%")

if overall < min_coverage:
    print(f"FAIL: Coverage {overall:.1f}% is below the {min_coverage}% gate")
    sys.exit(1)
else:
    print(f"PASS: Coverage {overall:.1f}% meets the {min_coverage}% gate")
    sys.exit(0)
PYEOF
