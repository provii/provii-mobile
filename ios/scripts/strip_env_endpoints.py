#!/usr/bin/env python3
# SPDX-License-Identifier: BUSL-1.1
# Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
#
# Strip non-release environment entries from api-endpoints.json.
#
# In release (archive) builds this script rewrites the bundled JSON so that
# only "production" and "sandbox" entries survive. "staging" and "development"
# entries are removed. The file is rewritten in place inside the built .app
# bundle; the source file in the repository is never modified.
#
# Xcode Run Script Build Phase setup:
#   Phase name:  "Strip Non-Release Environments"
#   Position:    after "Copy Bundle Resources", before "Code Signing"
#   Input files: $(SRCROOT)/ProviiWallet/Resources/api-endpoints.json
#   Script:      python3 "${SRCROOT}/scripts/strip_env_endpoints.py"
#
# The script is a no-op in DEBUG builds so local development is unaffected.

import json
import os
import sys

RELEASE_ALLOWLIST = {"production", "sandbox"}

# Xcode sets CONFIGURATION to "Release" for archive builds.
configuration = os.environ.get("CONFIGURATION", "")
if configuration != "Release":
    print(f"note: strip_env_endpoints: skipping (CONFIGURATION={configuration!r})")
    sys.exit(0)

built_products = os.environ.get("BUILT_PRODUCTS_DIR", "")
product_name = os.environ.get("FULL_PRODUCT_NAME", "")

if not built_products or not product_name:
    print("error: strip_env_endpoints: BUILT_PRODUCTS_DIR or FULL_PRODUCT_NAME not set")
    sys.exit(1)

target_path = os.path.join(built_products, product_name, "api-endpoints.json")

if not os.path.isfile(target_path):
    print(f"error: strip_env_endpoints: JSON not found at {target_path!r}")
    sys.exit(1)

with open(target_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

environments = data.get("environments", {})
removed = [k for k in list(environments.keys()) if k not in RELEASE_ALLOWLIST]

for key in removed:
    del environments[key]
    print(f"note: strip_env_endpoints: removed environment '{key}'")

data["environments"] = environments

with open(target_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")

retained = sorted(environments.keys())
print(f"note: strip_env_endpoints: retained environments: {retained}")
