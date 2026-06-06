// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.settings

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import app.provii.wallet.R
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.theme.cardFocusIndicator
import app.provii.wallet.ui.components.Breadcrumb
import app.provii.wallet.ui.components.BreadcrumbItem

/**
 * Data class representing an open source library licence
 */
private data class License(
    val name: String,
    val version: String? = null,
    val licenseType: String,
    val licenseText: String,
)

/**
 * Licences Screen - Displays open source licences for third-party libraries
 * Following WCAG 2.2 AAA accessibility guidelines
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LicensesScreen(navController: NavController) {
    // Group licences by type
    val licenseGroups =
        remember {
            licenses.groupBy { it.licenseType }
                .toSortedMap()
        }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        stringResource(R.string.licenses_title),
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.content_desc_back),
                        )
                    }
                },
            )
        },
    ) { paddingValues ->
        LazyColumn(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            contentPadding = PaddingValues(16.dp),
        ) {
            // Breadcrumb Navigation (WCAG 2.4.8 AAA)
            item {
                Breadcrumb(
                    items =
                        listOf(
                            BreadcrumbItem(stringResource(R.string.breadcrumb_settings)),
                            BreadcrumbItem(stringResource(R.string.licenses_title)),
                        ),
                    onNavigate = { index ->
                        when (index) {
                            0 -> navController.popBackStack()
                        }
                    },
                )
            }

            // Header section
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors =
                        CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                        ),
                ) {
                    Row(
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            Icons.Default.Description,
                            contentDescription = null, // Decorative
                            tint = MaterialTheme.colorScheme.primary,
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            stringResource(R.string.licenses_description),
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                    }
                }
            }

            // Licence groups
            licenseGroups.forEach { (licenseType, groupLicenses) ->
                item {
                    LicenseGroupHeader(
                        licenseType = licenseType,
                        count = groupLicenses.size,
                    )
                }

                items(groupLicenses) { license ->
                    LicenseCard(license = license)
                }
            }
        }
    }
}

/**
 * Header for a group of licences of the same type
 */
@Composable
private fun LicenseGroupHeader(
    licenseType: String,
    count: Int,
) {
    Text(
        text = stringResource(R.string.licenses_group_header, licenseType, count),
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        modifier =
            Modifier
                .padding(top = 8.dp, bottom = 4.dp)
                .semantics { heading() },
    )
}

/**
 * Expandable card for a single licence
 */
@Composable
private fun LicenseCard(license: License) {
    var isExpanded by remember { mutableStateOf(false) }
    val accessibilityUiState = LocalAccessibilityUiState.current
    val tapToViewText = stringResource(R.string.licenses_tap_to_view)

    val libraryDescription =
        if (license.version != null) {
            "${license.name} version ${license.version}"
        } else {
            license.name
        }

    val semanticDescription =
        if (isExpanded) {
            stringResource(R.string.licenses_accessibility_library_expanded, libraryDescription, license.licenseType)
        } else {
            stringResource(R.string.licenses_accessibility_library_collapsed, libraryDescription, license.licenseType, tapToViewText)
        }

    Card(
        modifier =
            Modifier
                .fillMaxWidth()
                .cardFocusIndicator()
                .semantics(mergeDescendants = true) {
                    this.stateDescription = semanticDescription
                    this.role = Role.Button
                }
                .clickable { isExpanded = !isExpanded },
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = license.name,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (license.version != null) {
                            Text(
                                text = stringResource(R.string.licenses_version_format, license.version),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = stringResource(R.string.licenses_bullet_separator),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                        }
                        Text(
                            text = license.licenseType,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
                Icon(
                    imageVector = if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = null, // Decorative - state is in semantics
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            AnimatedVisibility(
                visible = isExpanded,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically(),
            ) {
                Column {
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = license.licenseText,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        lineHeight = MaterialTheme.typography.bodySmall.lineHeight * accessibilityUiState.settings.lineSpacingMultiplier,
                    )
                }
            }
        }
    }
}

/**
 * List of all third-party licences used in the app
 * Based on THIRD_PARTY_LICENSES.md
 *
 * IMPORTANT: This list is hardcoded and must be manually updated when dependencies change.
 *
 * Last updated: 2026-02-22
 *
 * To update this list:
 * 1. Review build.gradle files for any new or updated dependencies
 * 2. Check THIRD_PARTY_LICENSES.md in the project root for the complete list
 * 3. Add/remove/update licences here to match current dependencies
 * 4. Update the "Last updated" date above
 *
 * Consider setting up an automated licence scanning tool (e.g., Gradle Licence Plugin)
 * to generate this list automatically in future.
 */
private val licenses =
    listOf(
        License(
            name = "AndroidX Libraries",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        License(
            name = "Kotlin",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        License(
            name = "Material Design Components",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        License(
            name = "Jetpack Compose",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        License(
            name = "YubiKey SDK",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        License(
            name = "ZXing",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        License(
            name = "Coil",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        License(
            name = "Timber",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        License(
            name = "OkHttp",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        License(
            name = "Retrofit",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        License(
            name = "Dagger Hilt",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        License(
            name = "JNA (Java Native Access)",
            version = "5.17.0",
            licenseType = "Apache License 2.0",
            licenseText = APACHE_2_LICENSE_TEXT,
        ),
        // Wallet SDK (Rust) dependencies compiled into native .so library
        License(
            name = "Rust Core Libraries (~400 crates)",
            licenseType = "MIT OR Apache-2.0",
            licenseText = MIT_OR_APACHE_SUMMARY_TEXT,
        ),
        License(
            name = "ed25519-dalek, curve25519-dalek, subtle",
            version = "2.2.0 / 4.1.3 / 2.6.1",
            licenseType = "BSD-3-Clause",
            licenseText = BSD_3_CLAUSE_LICENSE_TEXT,
        ),
        License(
            name = "UniFFI",
            version = "0.29.5",
            licenseType = "MPL-2.0",
            licenseText = MPL_2_SUMMARY_TEXT,
        ),
        License(
            name = "rustls, aws-lc-rs, webpki-roots",
            version = "0.23.36 / 1.15.2 / 0.26.11",
            licenseType = "Apache-2.0 / ISC / OpenSSL",
            licenseText = TLS_LIBRARIES_LICENSE_TEXT,
        ),
        License(
            name = "ICU4X Unicode Libraries",
            version = "2.1.x",
            licenseType = "Unicode-3.0",
            licenseText = UNICODE_3_SUMMARY_TEXT,
        ),
    )

/**
 * Apache License 2.0 full text
 */
private const val APACHE_2_LICENSE_TEXT = """Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License."""

private const val MIT_OR_APACHE_SUMMARY_TEXT = """Approximately 400 Rust crates are dual-licensed under MIT OR Apache-2.0, including: tokio (async runtime), serde (serialisation), hyper (HTTP), blake2 and sha2 (hashing), rand (randomness), chrono (date/time), anyhow (error handling), zeroize (memory clearing), quinn (QUIC transport), postcard (compact serialisation), hex, base64 (encoding), url, uuid, and many others. The full list is available in THIRD_PARTY_LICENSES.md."""

private const val BSD_3_CLAUSE_LICENSE_TEXT = """Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."""

private const val MPL_2_SUMMARY_TEXT = """This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

UniFFI is used as a build tool to generate Kotlin bindings for the Rust Wallet SDK. The generated bindings are Provii's own code and are not subject to the MPL. No modifications have been made to the UniFFI source code."""

private const val TLS_LIBRARIES_LICENSE_TEXT = """rustls is licensed under Apache-2.0 OR ISC OR MIT. aws-lc-rs and aws-lc-sys are licensed under ISC AND (Apache-2.0 OR ISC) AND OpenSSL. webpki-roots is licensed under CDLA-Permissive-2.0 (Community Data Licence Agreement). All are permissive licences that allow commercial use and binary distribution."""

private const val UNICODE_3_SUMMARY_TEXT = """The ICU4X crates (icu_collections, icu_locale_core, icu_normalizer, icu_properties, icu_provider, and related crates) are licensed under the Unicode Licence Agreement (Unicode-3.0). Permission is hereby granted, free of charge, to any person obtaining a copy of data files and any associated documentation, to deal in the data files without restriction."""
