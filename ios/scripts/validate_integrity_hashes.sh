#!/bin/bash
# SPDX-License-Identifier: BUSL-1.1
# Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
#
# ST-WM-001: Build-time validation that integrity hash placeholders have been
# replaced before release builds. Run this as a "Run Script" build phase in
# Xcode, AFTER the "Compute Integrity Hashes" phase.
#
# In debug builds this script exits successfully (placeholders are expected).
# In release builds it fails the build if any placeholder remains.

set -euo pipefail

INTEGRITY_CHECKER="${SRCROOT}/ProviiWallet/ProviiWallet/Core/Security/IntegrityChecker.swift"

if [ ! -f "$INTEGRITY_CHECKER" ]; then
    echo "error: IntegrityChecker.swift not found at $INTEGRITY_CHECKER"
    exit 1
fi

# In debug builds, placeholders are expected
if [ "${CONFIGURATION}" = "Debug" ]; then
    echo "note: Skipping integrity hash validation for Debug build"
    exit 0
fi

# In release builds, fail if any placeholder is still present
PLACEHOLDER="PLACEHOLDER_SET_DURING_BUILD"
MATCHES=$(grep -c "$PLACEHOLDER" "$INTEGRITY_CHECKER" || true)

if [ "$MATCHES" -gt 0 ]; then
    echo "error: IntegrityChecker.swift still contains $MATCHES placeholder hash value(s)."
    echo "error: The build script 'Compute Integrity Hashes' must replace all"
    echo "error: '$PLACEHOLDER' values with actual SHA-256 hashes before release."
    echo "error: See IntegrityChecker.swift comments for generation instructions."
    exit 1
fi

echo "note: Integrity hash validation passed (no placeholders found)"
exit 0
