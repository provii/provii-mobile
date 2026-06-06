#!/bin/bash
# SPDX-License-Identifier: BUSL-1.1
# Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
#
# Compute Integrity Hashes
#
# Computes SHA-256 hashes of the main executable and Info.plist inside the
# built .app bundle, then writes them to IntegrityHashes.json for runtime
# consumption by IntegrityChecker.swift.
#
# Xcode Run Script Build Phase Setup:
#   Phase name:  "Compute Integrity Hashes"
#   Position:    after "Link Binary With Libraries", before "Code Signing"
#   Script:      ${SRCROOT}/scripts/compute_integrity_hashes.sh "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
#
# The companion script validate_integrity_hashes.sh should run AFTER this
# phase to confirm placeholders have been replaced in release builds.

set -euo pipefail

APP_BUNDLE="${1:?Usage: compute_integrity_hashes.sh <path-to-.app-bundle>}"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "error: App bundle not found at ${APP_BUNDLE}"
    exit 1
fi

# Derive the executable name from the bundle
BUNDLE_NAME=$(basename "${APP_BUNDLE}" .app)
EXECUTABLE="${APP_BUNDLE}/${BUNDLE_NAME}"
INFO_PLIST="${APP_BUNDLE}/Info.plist"

if [ ! -f "${EXECUTABLE}" ]; then
    echo "error: Executable not found at ${EXECUTABLE}"
    exit 1
fi

if [ ! -f "${INFO_PLIST}" ]; then
    echo "error: Info.plist not found at ${INFO_PLIST}"
    exit 1
fi

# Compute SHA-256 hashes
EXEC_HASH=$(shasum -a 256 "${EXECUTABLE}" | awk '{print $1}')
PLIST_HASH=$(shasum -a 256 "${INFO_PLIST}" | awk '{print $1}')

echo "note: Executable hash: ${EXEC_HASH}"
echo "note: Info.plist hash: ${PLIST_HASH}"

# Write hashes to JSON file inside the bundle
HASHES_FILE="${APP_BUNDLE}/IntegrityHashes.json"
cat > "${HASHES_FILE}" << EOF
{
  "executableHash": "${EXEC_HASH}",
  "infoPlistHash": "${PLIST_HASH}"
}
EOF

echo "note: Integrity hashes written to ${HASHES_FILE}"
