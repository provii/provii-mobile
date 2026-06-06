// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.ui.screens.discovery

import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.automirrored.outlined.*
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import app.provii.wallet.ui.theme.ensureAAAContrastWithWhite
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import app.provii.wallet.LocalIssuersRepository
import app.provii.wallet.R
import app.provii.wallet.data.Issuer
import app.provii.wallet.data.IssuerRegistry
import app.provii.wallet.ui.accessibility.LocalAccessibilityUiState
import app.provii.wallet.ui.components.accessibility.AccessibleCard
import app.provii.wallet.ui.theme.buttonFocusIndicator
import kotlinx.coroutines.launch

/**
 * Issuer discovery screen that fetches and displays the available credential issuers
 * from the registry. Presents issuers in filterable categories with search, expandable
 * detail cards, and direct links to issuer websites. Supports TalkBack with live-region
 * announcements for loading, error, and empty-result states.
 */

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun WhereToGetCredentialsScreen(
    navController: NavController,
    filterMode: String? = null,
) {
    val issuersRepository = LocalIssuersRepository.current
    val coroutineScope = rememberCoroutineScope()
    val uriHandler = LocalUriHandler.current

    var registry by remember { mutableStateOf<IssuerRegistry?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var selectedCategory by remember { mutableStateOf("all") }
    var expandedIssuerId by remember { mutableStateOf<String?>(null) }

    // Apply top-level mode filter (apps only, locations only, or all)
    val modeFilteredIssuers: List<Issuer> =
        remember(registry, filterMode) {
            val all = registry?.issuers ?: emptyList()
            when (filterMode) {
                "apps" -> all.filter { !it.deepLink.isNullOrBlank() }
                "locations" -> all.filter { !it.locations.isNullOrEmpty() }
                else -> all
            }
        }

    LaunchedEffect(Unit) {
        coroutineScope.launch {
            isLoading = true
            registry = issuersRepository.loadIssuers()
            isLoading = false
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            stringResource(
                                when (filterMode) {
                                    "apps" -> R.string.title_find_apps
                                    "locations" -> R.string.title_find_locations
                                    else -> R.string.title_get_credentials
                                },
                            ),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.semantics { heading() },
                        )
                        Text(
                            stringResource(R.string.issuers_trusted_in_australia),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.accessibility_discovery_back_description))
                    }
                },
                actions = {
                    IconButton(onClick = {
                        coroutineScope.launch {
                            isLoading = true
                            issuersRepository.refreshIssuers()
                            registry = issuersRepository.loadIssuers()
                            isLoading = false
                        }
                    }) {
                        Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.accessibility_discovery_refresh_description))
                    }
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
            )
        },
    ) { paddingValues ->
        when {
            isLoading -> {
                Box(
                    modifier =
                        Modifier
                            .fillMaxSize()
                            .padding(paddingValues),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(48.dp),
                            strokeWidth = 3.dp,
                        )
                        Text(
                            stringResource(R.string.issuers_loading),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            registry == null || registry?.issuers?.isEmpty() == true -> {
                Box(
                    modifier =
                        Modifier
                            .fillMaxSize()
                            .padding(paddingValues),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(32.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        Icon(
                            Icons.Outlined.CloudOff,
                            contentDescription = null, // Decorative - error state is conveyed by accompanying text
                            modifier = Modifier.size(72.dp),
                            tint = MaterialTheme.colorScheme.error, // WCAG 1.4.11: Full contrast for error indication
                        )
                        Text(
                            text = stringResource(R.string.issuers_unable_to_load),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Medium,
                        )
                        Text(
                            text = stringResource(R.string.issuers_check_connection),
                            style = MaterialTheme.typography.bodyMedium,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Button(
                            onClick = {
                                coroutineScope.launch {
                                    isLoading = true
                                    issuersRepository.refreshIssuers()
                                    registry = issuersRepository.loadIssuers()
                                    isLoading = false
                                }
                            },
                            modifier = Modifier.padding(top = 8.dp),
                        ) {
                            Icon(
                                Icons.Default.Refresh,
                                contentDescription = null, // Decorative - button has text label
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(stringResource(R.string.action_try_again))
                        }
                    }
                }
            }

            // Mode filter produced zero results (registry loaded fine, but no matching issuers)
            filterMode != null && modeFilteredIssuers.isEmpty() -> {
                Box(
                    modifier =
                        Modifier
                            .fillMaxSize()
                            .padding(paddingValues),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(32.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        Icon(
                            if (filterMode == "apps") Icons.Outlined.PhoneAndroid else Icons.Outlined.LocationOn,
                            contentDescription = null, // Decorative - empty state is conveyed by accompanying text
                            modifier = Modifier.size(72.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            text =
                                stringResource(
                                    if (filterMode == "apps") {
                                        R.string.issuers_no_apps_found
                                    } else {
                                        R.string.issuers_no_locations_found
                                    },
                                ),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Medium,
                        )
                        Text(
                            text =
                                stringResource(
                                    if (filterMode == "apps") {
                                        R.string.issuers_no_apps_found_description
                                    } else {
                                        R.string.issuers_no_locations_found_description
                                    },
                                ),
                            style = MaterialTheme.typography.bodyMedium,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            else -> {
                // Announce loading completion to screen readers
                val loadingCompleteMessage = stringResource(R.string.issuers_loaded)
                LaunchedEffect(registry) {
                    if (registry != null) {
                        // Loading complete announcement handled via live region below
                    }
                }

                LazyColumn(
                    modifier =
                        Modifier
                            .fillMaxSize()
                            .padding(paddingValues)
                            .background(MaterialTheme.colorScheme.background),
                    contentPadding = PaddingValues(bottom = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(0.dp),
                ) {
                    // Accessibility announcement for loading completion
                    item {
                        Text(
                            text = loadingCompleteMessage,
                            modifier =
                                Modifier
                                    .height(0.dp)
                                    .semantics {
                                        liveRegion = LiveRegionMode.Polite
                                    },
                        )
                    }

                    // Header Card
                    item {
                        Surface(
                            modifier = Modifier.fillMaxWidth(),
                            color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f),
                        ) {
                            Row(
                                modifier = Modifier.padding(20.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Icon(
                                    Icons.Default.Info,
                                    contentDescription = null, // Decorative - information is conveyed by accompanying text
                                    modifier = Modifier.size(24.dp),
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Text(
                                    text = registry?.description ?: "",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurface,
                                )
                            }
                        }
                    }

                    // Category Filters
                    registry?.categories?.let { categories ->
                        item {
                            Column {
                                Text(
                                    text = stringResource(R.string.issuers_categories_header),
                                    modifier =
                                        Modifier
                                            .padding(horizontal = 20.dp, vertical = 16.dp)
                                            .semantics { heading() },
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    letterSpacing = 1.sp,
                                )
                                // WCAG 1.4.10: Use FlowRow to allow content to reflow
                                // without requiring horizontal scrolling at 320dp width
                                FlowRow(
                                    modifier =
                                        Modifier
                                            .fillMaxWidth()
                                            .padding(horizontal = 16.dp),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    verticalArrangement = Arrangement.spacedBy(8.dp),
                                ) {
                                    categories.forEach { category ->
                                        val isSelected = selectedCategory == category.id
                                        val chipStateDesc =
                                            if (isSelected) {
                                                stringResource(R.string.accessibility_state_selected)
                                            } else {
                                                stringResource(R.string.accessibility_state_not_selected)
                                            }
                                        FilterChip(
                                            selected = isSelected,
                                            onClick = {
                                                selectedCategory = category.id
                                                expandedIssuerId = null
                                            },
                                            label = {
                                                Text(
                                                    category.name,
                                                    style = MaterialTheme.typography.labelLarge,
                                                )
                                            },
                                            leadingIcon =
                                                if (isSelected) {
                                                    {
                                                        Icon(
                                                            Icons.Default.Check,
                                                            contentDescription = null, // Decorative - FilterChip conveys selected state
                                                            modifier = Modifier.size(18.dp),
                                                        )
                                                    }
                                                } else {
                                                    null
                                                },
                                            colors =
                                                FilterChipDefaults.filterChipColors(
                                                    selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                                                ),
                                            modifier =
                                                Modifier.semantics {
                                                    stateDescription = chipStateDesc
                                                },
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Issuers Section Header
                    item {
                        val filteredIssuers =
                            if (selectedCategory == "all") {
                                modeFilteredIssuers
                            } else {
                                modeFilteredIssuers.filter { it.category == selectedCategory }
                            }

                        Row(
                            modifier =
                                Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 20.dp, vertical = 16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = stringResource(R.string.issuers_available_header),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                letterSpacing = 1.sp,
                            )
                            Text(
                                text = stringResource(R.string.issuers_found_count, filteredIssuers.size),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier =
                                    Modifier.semantics {
                                        liveRegion = LiveRegionMode.Polite
                                    },
                            )
                        }
                    }

                    // Issuer Cards (uses modeFilteredIssuers to match the header count)
                    val filteredIssuers =
                        if (selectedCategory == "all") {
                            modeFilteredIssuers
                        } else {
                            modeFilteredIssuers.filter { it.category == selectedCategory }
                        }

                    items(
                        items = filteredIssuers,
                        key = { it.id },
                    ) { issuer ->
                        val isExpanded = expandedIssuerId == issuer.id
                        ImprovedIssuerCard(
                            issuer = issuer,
                            isExpanded = isExpanded,
                            onExpandToggle = {
                                expandedIssuerId = if (expandedIssuerId == issuer.id) null else issuer.id
                            },
                            onWebsiteClick = {
                                val uri = Uri.parse(issuer.website)
                                if (uri.scheme?.lowercase() == "https") {
                                    uriHandler.openUri(issuer.website)
                                }
                            },
                        )
                    }

                    // Bottom spacing
                    item {
                        Spacer(modifier = Modifier.height(16.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun ImprovedIssuerCard(
    issuer: Issuer,
    isExpanded: Boolean,
    onExpandToggle: () -> Unit,
    onWebsiteClick: () -> Unit,
) {
    val stateDesc =
        if (isExpanded) {
            stringResource(R.string.accessibility_state_expanded)
        } else {
            stringResource(R.string.accessibility_state_collapsed)
        }

    AccessibleCard(
        modifier =
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 6.dp)
                .animateContentSize()
                .semantics {
                    stateDescription = stateDesc
                },
        onClick = onExpandToggle,
        contentDescription = issuer.name,
        colors =
            CardDefaults.cardColors(
                containerColor =
                    when (issuer.status) {
                        "coming_soon" -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                        else -> MaterialTheme.colorScheme.surface
                    },
            ),
        elevation =
            CardDefaults.cardElevation(
                defaultElevation = if (isExpanded) 8.dp else 2.dp,
            ),
    ) {
        Column {
            // Main Content Row
            // Calculate brand colour outside of background modifier to avoid try-catch in composable
            val fallbackColor = MaterialTheme.colorScheme.primary
            val brandBackgroundColor =
                remember(issuer.brandColor, fallbackColor) {
                    try {
                        // Validate brand colour meets WCAG AAA contrast (7:1) with white text
                        val parsedColor = Color(android.graphics.Color.parseColor(issuer.brandColor))
                        ensureAAAContrastWithWhite(parsedColor, fallbackColor)
                    } catch (e: Exception) {
                        fallbackColor
                    }
                }
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                verticalAlignment = Alignment.Top,
            ) {
                // Logo/Brand Colour Box
                Box(
                    modifier =
                        Modifier
                            .size(56.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(brandBackgroundColor),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = issuer.name.take(2).uppercase(),
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    )
                }

                Spacer(modifier = Modifier.width(16.dp))

                // Content
                Column(modifier = Modifier.weight(1f)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            text = issuer.name,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.weight(1f),
                        )

                        // Status Indicators
                        when (issuer.status) {
                            "coming_soon" -> {
                                AssistChip(
                                    onClick = { },
                                    label = {
                                        Text(
                                            stringResource(R.string.issuer_status_coming_soon),
                                            style = MaterialTheme.typography.labelSmall,
                                        )
                                    },
                                    modifier = Modifier.height(24.dp),
                                    colors =
                                        AssistChipDefaults.assistChipColors(
                                            containerColor = MaterialTheme.colorScheme.tertiaryContainer,
                                        ),
                                )
                            }
                            else -> {
                                if (issuer.verified) {
                                    Icon(
                                        Icons.Default.Verified,
                                        contentDescription = stringResource(R.string.accessibility_discovery_verified_description),
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(20.dp),
                                    )
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(4.dp))

                    Text(
                        text = issuer.description,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = if (isExpanded) Int.MAX_VALUE else 1,
                        overflow = TextOverflow.Ellipsis,
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Category Badge
                    Surface(
                        shape = RoundedCornerShape(4.dp),
                        color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.5f),
                    ) {
                        Text(
                            text = getCategoryDisplayName(issuer.category),
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSecondaryContainer,
                        )
                    }
                }

                // Expand/Collapse Icon - WCAG 2.5.5: Minimum 44dp touch target
                IconButton(onClick = onExpandToggle) {
                    val contentDesc = stringResource(if (isExpanded) R.string.action_collapse else R.string.action_expand)
                    Icon(
                        imageVector = if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                        contentDescription = contentDesc,
                        modifier = Modifier.size(24.dp), // Size icon, not button
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // Expanded Content
            // WCAG 2.3.3: Respect reduce motion setting
            val accessibilityUiState = LocalAccessibilityUiState.current
            val reduceMotion = accessibilityUiState.settings.reduceMotion || accessibilityUiState.prefersReducedMotion

            AnimatedVisibility(
                visible = isExpanded,
                enter = if (reduceMotion) EnterTransition.None else (expandVertically() + fadeIn()),
                exit = if (reduceMotion) ExitTransition.None else (shrinkVertically() + fadeOut()),
            ) {
                Column {
                    HorizontalDivider(
                        modifier = Modifier.padding(horizontal = 16.dp),
                        color = MaterialTheme.colorScheme.outlineVariant,
                    )

                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        // Instructions Section
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.AutoMirrored.Outlined.Assignment,
                                    contentDescription = null, // Decorative - section header has text label
                                    modifier = Modifier.size(20.dp),
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = stringResource(R.string.issuer_how_to_get),
                                    style = MaterialTheme.typography.labelLarge,
                                    fontWeight = FontWeight.Medium,
                                )
                            }

                            Surface(
                                shape = RoundedCornerShape(8.dp),
                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                            ) {
                                Text(
                                    text = issuer.instructions,
                                    modifier = Modifier.padding(12.dp),
                                    style = MaterialTheme.typography.bodyMedium,
                                )
                            }
                        }

                        // Locations (if available)
                        issuer.locations?.let { locations ->
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        Icons.Outlined.LocationOn,
                                        contentDescription = null, // Decorative - section header has text label
                                        modifier = Modifier.size(20.dp),
                                        tint = MaterialTheme.colorScheme.primary,
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = stringResource(R.string.issuer_service_locations),
                                        style = MaterialTheme.typography.labelLarge,
                                        fontWeight = FontWeight.Medium,
                                    )
                                }

                                locations.forEach { location ->
                                    Card(
                                        colors =
                                            CardDefaults.cardColors(
                                                containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.3f),
                                            ),
                                        modifier = Modifier.fillMaxWidth(),
                                    ) {
                                        Column(
                                            modifier = Modifier.padding(12.dp),
                                            verticalArrangement = Arrangement.spacedBy(4.dp),
                                        ) {
                                            Text(
                                                text = location.name,
                                                style = MaterialTheme.typography.labelLarge,
                                                fontWeight = FontWeight.Medium,
                                            )
                                            Row(verticalAlignment = Alignment.Top) {
                                                Icon(
                                                    Icons.Outlined.Place,
                                                    contentDescription = null, // Decorative - address is conveyed by accompanying text
                                                    modifier = Modifier.size(16.dp),
                                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                                )
                                                Spacer(modifier = Modifier.width(4.dp))
                                                Text(
                                                    text = location.address,
                                                    style = MaterialTheme.typography.bodySmall,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                )
                                            }
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Icon(
                                                    Icons.Outlined.Schedule,
                                                    contentDescription = null, // Decorative - hours are conveyed by accompanying text
                                                    modifier = Modifier.size(16.dp),
                                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                                )
                                                Spacer(modifier = Modifier.width(4.dp))
                                                Text(
                                                    text = location.hours,
                                                    style = MaterialTheme.typography.bodySmall,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Action Buttons
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            if (issuer.status != "coming_soon") {
                                Button(
                                    onClick = onWebsiteClick,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Icon(
                                        Icons.AutoMirrored.Filled.OpenInNew,
                                        contentDescription = null, // Decorative - button has text label
                                        modifier = Modifier.size(18.dp),
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(stringResource(R.string.issuer_visit_website, issuer.name))
                                }
                            } else {
                                OutlinedButton(
                                    onClick = onWebsiteClick,
                                    modifier =
                                        Modifier
                                            .weight(1f)
                                            .buttonFocusIndicator(),
                                ) {
                                    Icon(
                                        Icons.Default.Info,
                                        contentDescription = null, // Decorative - button has text label
                                        modifier = Modifier.size(18.dp),
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(stringResource(R.string.issuer_learn_more, issuer.name))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun getCategoryDisplayName(category: String): String {
    return when (category) {
        "financial" -> stringResource(R.string.category_banking)
        "superannuation" -> stringResource(R.string.category_super_fund)
        "government" -> stringResource(R.string.category_government)
        "travel" -> stringResource(R.string.category_travel)
        "telecommunications" -> stringResource(R.string.category_telco)
        "insurance" -> stringResource(R.string.category_insurance)
        else -> category.replaceFirstChar { it.uppercase() }
    }
}
