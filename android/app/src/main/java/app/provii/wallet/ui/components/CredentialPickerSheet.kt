// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Badge
import androidx.compose.material.icons.outlined.ChildCare
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.CollectionInfo
import androidx.compose.ui.semantics.CollectionItemInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.collectionInfo
import androidx.compose.ui.semantics.collectionItemInfo
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.provii.wallet.R
import app.provii.wallet.data.WalletRepository
import app.provii.wallet.ui.theme.buttonFocusIndicator
import app.provii.wallet.ui.theme.cardFocusIndicator

/**
 * Bottom sheet credential picker shared by QR scanner and deep link verification flows.
 * Displays the user's credentials grouped into "Me" and "Managed Credentials" sections,
 * sorted with the primary credential first, followed by managed credentials in
 * alphabetical order. No suitability pre-filtering is performed because dob_days is a
 * zero knowledge proof secret and not exposed to the UI layer.
 *
 * Constrained to 60% of screen height with a 300dp minimum.
 */
@Composable
fun CredentialPickerSheet(
    credentials: List<WalletRepository.CredentialPickerItem>,
    onCredentialSelected: (WalletRepository.CredentialPickerItem) -> Unit,
    onDismiss: () -> Unit,
) {
    // Sort: primary first, then managed alphabetically by displayName
    val sorted =
        credentials.sortedWith(
            compareBy<WalletRepository.CredentialPickerItem> { it.isManaged }
                .thenBy { it.displayName.orEmpty().lowercase() },
        )

    val primaryCredentials = sorted.filter { !it.isManaged }
    val managedCredentials = sorted.filter { it.isManaged }

    // Height constraint: 60% of screen height, scaling up with font size, minimum 300dp
    val configuration = LocalConfiguration.current
    val screenHeightDp = configuration.screenHeightDp.dp
    val fontScale = LocalDensity.current.fontScale
    val maxSheetFraction = (0.6f + (fontScale - 1f) * 0.15f).coerceAtMost(0.9f)
    val maxSheetHeight = screenHeightDp * maxSheetFraction

    // Focus management: direct TalkBack to the sheet title on open
    val titleFocusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(300)
        titleFocusRequester.requestFocus()
    }

    val sheetTitle = stringResource(R.string.credential_picker_title)

    Column(
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(min = 300.dp, max = maxSheetHeight)
                .padding(horizontal = 24.dp, vertical = 16.dp)
                .semantics { paneTitle = sheetTitle },
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            sheetTitle,
            style = MaterialTheme.typography.titleLarge,
            modifier =
                Modifier
                    .focusRequester(titleFocusRequester)
                    .semantics { heading() },
        )
        Text(
            stringResource(R.string.credential_picker_subtitle),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        // Total row count for collection semantics
        val totalRowCount = primaryCredentials.size + managedCredentials.size

        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(0.dp),
            modifier =
                Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .semantics {
                        collectionInfo =
                            CollectionInfo(
                                rowCount = totalRowCount,
                                columnCount = 1,
                            )
                    },
        ) {
            // -- "Me" section header --
            if (primaryCredentials.isNotEmpty()) {
                item(key = "section_me") {
                    Text(
                        text = stringResource(R.string.credential_picker_section_me),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier =
                            Modifier
                                .padding(vertical = 8.dp)
                                .semantics { heading() },
                    )
                }
            }

            // -- Primary credential rows --
            itemsIndexed(
                items = primaryCredentials,
                key = { _, item -> item.id },
            ) { index, credential ->
                PickerCredentialRow(
                    credential = credential,
                    rowIndex = index,
                    onCredentialSelected = onCredentialSelected,
                )
            }

            // -- "Managed Credentials" section header --
            if (managedCredentials.isNotEmpty()) {
                item(key = "section_managed") {
                    Text(
                        text = stringResource(R.string.credential_picker_section_managed),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier =
                            Modifier
                                .padding(top = 12.dp, bottom = 8.dp)
                                .semantics { heading() },
                    )
                }
            }

            // -- Managed credential rows --
            itemsIndexed(
                items = managedCredentials,
                key = { _, item -> item.id },
            ) { index, credential ->
                PickerCredentialRow(
                    credential = credential,
                    rowIndex = primaryCredentials.size + index,
                    onCredentialSelected = onCredentialSelected,
                )
            }
        }

        TextButton(
            onClick = onDismiss,
            modifier =
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp)
                    .buttonFocusIndicator(),
        ) {
            Text(stringResource(R.string.action_cancel))
        }
    }
}

/**
 * Individual credential row used within the picker LazyColumn. Handles both primary
 * and managed credentials with appropriate icon, label, and semantics.
 */
@Composable
private fun PickerCredentialRow(
    credential: WalletRepository.CredentialPickerItem,
    rowIndex: Int,
    onCredentialSelected: (WalletRepository.CredentialPickerItem) -> Unit,
) {
    val talkBackLabel =
        if (credential.isManaged) {
            stringResource(R.string.credential_type_managed)
        } else {
            credential.displayName ?: stringResource(R.string.credential_section_my_credential)
        }

    Column {
        // A11Y-014a: Merge descendants so TalkBack reads the card
        // as a single accessible element with the credential name
        // and type, rather than announcing each child separately.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier =
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 56.dp)
                    .cardFocusIndicator()
                    .semantics(mergeDescendants = true) {
                        contentDescription = talkBackLabel
                        role = Role.Button
                        collectionItemInfo =
                            CollectionItemInfo(
                                rowIndex = rowIndex,
                                rowSpan = 1,
                                columnIndex = 0,
                                columnSpan = 1,
                            )
                    }
                    .clickable(
                        onClickLabel =
                            stringResource(
                                R.string.credential_picker_accessibility_select,
                                talkBackLabel,
                            ),
                    ) { onCredentialSelected(credential) }
                    .padding(vertical = 12.dp, horizontal = 4.dp),
        ) {
            // Type-appropriate icon
            Box(
                modifier =
                    Modifier
                        .size(40.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(
                            if (credential.isManaged) {
                                MaterialTheme.colorScheme.secondaryContainer
                            } else {
                                MaterialTheme.colorScheme.primaryContainer
                            },
                        ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    if (credential.isManaged) {
                        Icons.Outlined.ChildCare
                    } else {
                        Icons.Outlined.Badge
                    },
                    contentDescription = null,
                    modifier = Modifier.size(22.dp),
                    tint =
                        if (credential.isManaged) {
                            MaterialTheme.colorScheme.onSecondaryContainer
                        } else {
                            MaterialTheme.colorScheme.onPrimaryContainer
                        },
                )
            }

            Spacer(modifier = Modifier.width(16.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = credential.displayName ?: stringResource(R.string.credential_section_my_credential),
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                    // Privacy: prevent TalkBack from reading managed child names
                    // via individual node traversal
                    modifier =
                        if (credential.isManaged) {
                            Modifier.clearAndSetSemantics {}
                        } else {
                            Modifier
                        },
                )
                if (credential.isManaged) {
                    Text(
                        text = stringResource(R.string.credential_managed_label),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                // The canProve filter in getPickerCredentials() excludes expired credentials
                // because canProve is only true when status == VALID, and VALID and EXPIRED
                // are mutually exclusive in the SDK. This expired label UI is retained as a
                // defensive measure in case the filter is ever relaxed. Under normal
                // operation this branch will not trigger.
                if (credential.isExpired) {
                    Text(
                        text = stringResource(R.string.credential_picker_expired_label),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }

            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    }
}
