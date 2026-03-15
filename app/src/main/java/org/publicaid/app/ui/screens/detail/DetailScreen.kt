package org.publicaid.app.ui.screens.detail

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.publicaid.app.data.model.EntityHours
import org.publicaid.app.ui.components.ErrorState
import org.publicaid.app.ui.components.LoadingIndicator
import org.publicaid.app.util.IntentHelper

private val dayNames = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun DetailScreen(
    onBack: () -> Unit,
    viewModel: DetailViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val isBookmarked by viewModel.isBookmarked.collectAsStateWithLifecycle()
    val context = LocalContext.current

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        state.entity?.name ?: "",
                        maxLines = 1,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.toggleBookmark() }) {
                        Icon(
                            imageVector = if (isBookmarked) Icons.Default.Bookmark
                            else Icons.Outlined.BookmarkBorder,
                            contentDescription = if (isBookmarked) "Remove bookmark" else "Save",
                            tint = if (isBookmarked) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
            )
        },
    ) { padding ->
        when {
            state.isLoading -> LoadingIndicator(Modifier.padding(padding))
            state.error != null -> ErrorState(
                message = state.error!!,
                onRetry = { viewModel.loadEntity() },
                modifier = Modifier.padding(padding),
            )
            state.entity != null -> {
                val entity = state.entity!!

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .verticalScroll(rememberScrollState()),
                ) {
                    // Action buttons row
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        // Call
                        entity.phone?.let { phone ->
                            FilledTonalButton(
                                onClick = { IntentHelper.dial(context, phone) },
                                modifier = Modifier.weight(1f),
                            ) {
                                Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(6.dp))
                                Text("Call")
                            }
                        }
                        // Navigate
                        if (entity.lat != null && entity.lng != null) {
                            FilledTonalButton(
                                onClick = {
                                    IntentHelper.navigate(context, entity.lat!!, entity.lng!!, entity.name)
                                },
                                modifier = Modifier.weight(1f),
                            ) {
                                Icon(Icons.Default.Directions, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(6.dp))
                                Text("Navigate")
                            }
                        }
                        // Share
                        FilledTonalButton(
                            onClick = { IntentHelper.share(context, entity.name, entity.slug) },
                            modifier = Modifier.weight(1f),
                        ) {
                            Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("Share")
                        }
                    }

                    HorizontalDivider()

                    // Info section
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        // Description
                        entity.description?.let { desc ->
                            Text(
                                text = desc,
                                style = MaterialTheme.typography.bodyLarge,
                            )
                        }

                        // Contact info
                        InfoSection("Contact") {
                            entity.phone?.let { phone ->
                                InfoRow(Icons.Default.Phone, phone)
                            }
                            entity.intakePhone?.let { phone ->
                                InfoRow(Icons.Default.PhoneCallback, "Intake: $phone")
                            }
                            entity.website?.let { url ->
                                InfoRow(Icons.Default.Language, url) {
                                    IntentHelper.openUrl(context, url)
                                }
                            }
                        }

                        // Address
                        val address = entity.addressLine
                        if (address.isNotBlank()) {
                            InfoSection("Address") {
                                InfoRow(Icons.Default.LocationOn, address) {
                                    if (entity.lat != null && entity.lng != null) {
                                        IntentHelper.navigate(context, entity.lat!!, entity.lng!!, entity.name)
                                    }
                                }
                            }
                        }

                        // Hours
                        if (state.hours.isNotEmpty()) {
                            InfoSection("Hours") {
                                state.hours.sortedBy { it.dayOfWeek }.forEach { hours ->
                                    HoursRow(hours)
                                }
                            }
                        }

                        // Services
                        if (state.services.isNotEmpty()) {
                            InfoSection("Services") {
                                state.services.forEach { service ->
                                    Column(modifier = Modifier.padding(vertical = 4.dp)) {
                                        Text(
                                            text = service.name,
                                            style = MaterialTheme.typography.titleMedium,
                                        )
                                        service.description?.let {
                                            Text(
                                                text = it,
                                                style = MaterialTheme.typography.bodyMedium,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            )
                                        }
                                        service.eligibility?.let {
                                            Text(
                                                text = "Eligibility: $it",
                                                style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            )
                                        }
                                        service.fees?.let {
                                            Text(
                                                text = "Fees: $it",
                                                style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        // Categories
                        if (entity.categories.isNotEmpty()) {
                            InfoSection("Categories") {
                                FlowRow(
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    verticalArrangement = Arrangement.spacedBy(4.dp),
                                ) {
                                    entity.categories.forEach { cat ->
                                        SuggestionChip(
                                            onClick = {},
                                            label = { Text(cat.name) },
                                        )
                                    }
                                }
                            }
                        }

                        // Additional info
                        val extras = listOfNotNull(
                            entity.languages.takeIf { it.isNotEmpty() }?.let {
                                "Languages" to it.joinToString(", ")
                            },
                            entity.paymentTypes.takeIf { it.isNotEmpty() }?.let {
                                "Payment" to it.joinToString(", ")
                            },
                            entity.populationsServed.takeIf { it.isNotEmpty() }?.let {
                                "Populations served" to it.joinToString(", ")
                            },
                            entity.accessibility.takeIf { it.isNotEmpty() }?.let {
                                "Accessibility" to it.joinToString(", ")
                            },
                        )
                        if (extras.isNotEmpty()) {
                            InfoSection("Details") {
                                extras.forEach { (label, value) ->
                                    Column(modifier = Modifier.padding(vertical = 2.dp)) {
                                        Text(
                                            text = label,
                                            style = MaterialTheme.typography.labelLarge,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                        Text(
                                            text = value,
                                            style = MaterialTheme.typography.bodyMedium,
                                        )
                                    }
                                }
                            }
                        }

                        // Data quality footer
                        entity.dataQuality?.let { dq ->
                            HorizontalDivider()
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(16.dp),
                            ) {
                                Text(
                                    text = "${dq.sourceCount} source${if (dq.sourceCount != 1) "s" else ""}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                                if (dq.isVerified) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                                    ) {
                                        Icon(
                                            Icons.Default.Verified,
                                            contentDescription = null,
                                            modifier = Modifier.size(14.dp),
                                            tint = MaterialTheme.colorScheme.tertiary,
                                        )
                                        Text(
                                            text = "Verified",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.tertiary,
                                        )
                                    }
                                }
                            }
                        }

                        Spacer(Modifier.height(32.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun InfoSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.padding(bottom = 8.dp),
        )
        content()
    }
}

@Composable
private fun InfoRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    text: String,
    onClick: (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .then(
                if (onClick != null) Modifier.clickable(onClick = onClick)
                else Modifier
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(20.dp),
        )
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = if (onClick != null) MaterialTheme.colorScheme.primary
            else MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun HoursRow(hours: EntityHours) {
    val day = dayNames.getOrElse(hours.dayOfWeek) { "?" }
    val time = when {
        hours.isClosed -> "Closed"
        hours.openTime != null && hours.closeTime != null -> "${hours.openTime} – ${hours.closeTime}"
        else -> "Hours not available"
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = day,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.width(48.dp),
        )
        Text(
            text = time,
            style = MaterialTheme.typography.bodyMedium,
            color = if (hours.isClosed) MaterialTheme.colorScheme.error
            else MaterialTheme.colorScheme.onSurface,
        )
    }
}
