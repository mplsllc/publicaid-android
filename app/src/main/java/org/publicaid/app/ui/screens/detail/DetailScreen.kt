package org.publicaid.app.ui.screens.detail

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight

import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.publicaid.app.data.model.EntityHours
import org.publicaid.app.ui.components.ErrorState
import org.publicaid.app.ui.components.LoadingIndicator
import org.publicaid.app.ui.theme.LocalExtendedColors
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
    val colors = LocalExtendedColors.current

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
                            tint = if (isBookmarked) colors.brightBlue
                            else colors.mediumGray,
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
                        // Get Directions
                        if (entity.lat != null && entity.lng != null) {
                            Button(
                                onClick = {
                                    IntentHelper.navigate(context, entity.lat!!, entity.lng!!, entity.name)
                                },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = colors.brightBlue,
                                ),
                                modifier = Modifier.weight(1f),
                            ) {
                                Icon(Icons.Default.Directions, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(6.dp))
                                Text("Directions")
                            }
                        }
                        // Share
                        OutlinedButton(
                            onClick = { IntentHelper.share(context, entity.name, entity.slug) },
                            colors = ButtonDefaults.outlinedButtonColors(
                                contentColor = colors.grayText,
                            ),
                            border = BorderStroke(1.dp, colors.cardBorder),
                            modifier = Modifier.weight(1f),
                        ) {
                            Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("Share")
                        }
                    }

                    HorizontalDivider(color = colors.cardBorder)

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

                        // Contact info card
                        val hasContact = entity.phone != null || entity.intakePhone != null || entity.website != null
                        if (hasContact) {
                            Surface(
                                color = MaterialTheme.colorScheme.background,
                                shape = RoundedCornerShape(8.dp),
                                border = BorderStroke(1.dp, colors.cardBorder),
                            ) {
                                Column(
                                    modifier = Modifier.padding(16.dp),
                                    verticalArrangement = Arrangement.spacedBy(12.dp),
                                ) {
                                    SectionLabel("Contact")

                                    entity.phone?.let { phone ->
                                        Text(
                                            text = phone,
                                            style = MaterialTheme.typography.titleLarge,
                                            fontWeight = FontWeight.SemiBold,
                                            color = colors.brightBlue,
                                            modifier = Modifier.clickable { IntentHelper.dial(context, phone) },
                                        )
                                    }
                                    entity.intakePhone?.let { phone ->
                                        Column {
                                            SectionLabel("Intake")
                                            Text(
                                                text = phone,
                                                style = MaterialTheme.typography.bodyMedium,
                                                color = colors.brightBlue,
                                                modifier = Modifier.clickable { IntentHelper.dial(context, phone) },
                                            )
                                        }
                                    }
                                    entity.website?.let { url ->
                                        Column {
                                            SectionLabel("Website")
                                            Text(
                                                text = url,
                                                style = MaterialTheme.typography.bodyMedium,
                                                color = colors.brightBlue,
                                                modifier = Modifier.clickable { IntentHelper.openUrl(context, url) },
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        // Address
                        val address = entity.addressLine
                        if (address.isNotBlank()) {
                            Surface(
                                color = MaterialTheme.colorScheme.background,
                                shape = RoundedCornerShape(8.dp),
                                border = BorderStroke(1.dp, colors.cardBorder),
                            ) {
                                Column(modifier = Modifier.padding(16.dp)) {
                                    SectionLabel("Address")
                                    Text(
                                        text = address,
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = colors.brightBlue,
                                        modifier = Modifier.clickable {
                                            if (entity.lat != null && entity.lng != null) {
                                                IntentHelper.navigate(context, entity.lat!!, entity.lng!!, entity.name)
                                            }
                                        },
                                    )
                                }
                            }
                        }

                        // Hours
                        if (state.hours.isNotEmpty()) {
                            Column {
                                SectionLabel("Hours")
                                Spacer(Modifier.height(8.dp))
                                state.hours.sortedBy { it.dayOfWeek }.forEachIndexed { index, hours ->
                                    HoursRow(
                                        hours = hours,
                                        striped = index % 2 == 0,
                                    )
                                }
                            }
                        }

                        // Services
                        if (state.services.isNotEmpty()) {
                            Column {
                                SectionLabel("Services")
                                Spacer(Modifier.height(8.dp))
                                state.services.forEach { service ->
                                    Surface(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(vertical = 4.dp),
                                        color = MaterialTheme.colorScheme.background,
                                        shape = RoundedCornerShape(8.dp),
                                        border = BorderStroke(1.dp, colors.cardBorder),
                                    ) {
                                        Column(modifier = Modifier.padding(12.dp)) {
                                            Text(
                                                text = service.name,
                                                style = MaterialTheme.typography.titleMedium,
                                                color = colors.navyBlue,
                                            )
                                            service.description?.let {
                                                Text(
                                                    text = it,
                                                    style = MaterialTheme.typography.bodyMedium,
                                                    color = colors.grayText,
                                                )
                                            }
                                            service.eligibility?.let {
                                                Text(
                                                    text = "Eligibility: $it",
                                                    style = MaterialTheme.typography.bodySmall,
                                                    color = colors.grayText,
                                                )
                                            }
                                            service.fees?.let {
                                                Text(
                                                    text = "Fees: $it",
                                                    style = MaterialTheme.typography.bodySmall,
                                                    color = colors.grayText,
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Categories
                        if (entity.categories.isNotEmpty()) {
                            Column {
                                SectionLabel("Categories")
                                Spacer(Modifier.height(8.dp))
                                FlowRow(
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    verticalArrangement = Arrangement.spacedBy(4.dp),
                                ) {
                                    entity.categories.forEach { cat ->
                                        Surface(
                                            color = colors.tagBg,
                                            shape = RoundedCornerShape(50),
                                        ) {
                                            Text(
                                                text = cat.name,
                                                style = MaterialTheme.typography.labelSmall,
                                                color = colors.brightBlue,
                                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                                            )
                                        }
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
                                "Populations Served" to it.joinToString(", ")
                            },
                            entity.accessibility.takeIf { it.isNotEmpty() }?.let {
                                "Accessibility" to it.joinToString(", ")
                            },
                        )
                        if (extras.isNotEmpty()) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                SectionLabel("Details")
                                extras.forEach { (label, value) ->
                                    Column(modifier = Modifier.padding(vertical = 2.dp)) {
                                        Text(
                                            text = label.uppercase(),
                                            style = MaterialTheme.typography.labelSmall,
                                            color = colors.mediumGray,
                                            letterSpacing = 1.sp,
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
                            HorizontalDivider(color = colors.cardBorder)
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(16.dp),
                            ) {
                                Text(
                                    text = "${dq.sourceCount} source${if (dq.sourceCount != 1) "s" else ""}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = colors.grayText,
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
                                            tint = colors.greenAccent,
                                        )
                                        Text(
                                            text = "Verified",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = colors.greenAccent,
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
private fun SectionLabel(text: String) {
    val colors = LocalExtendedColors.current
    Text(
        text = text.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        color = colors.mediumGray,
        letterSpacing = 1.5.sp,
        fontWeight = FontWeight.Medium,
    )
}

@Composable
private fun HoursRow(hours: EntityHours, striped: Boolean = false) {
    val colors = LocalExtendedColors.current
    val day = dayNames.getOrElse(hours.dayOfWeek) { "?" }
    val time = when {
        hours.isClosed -> "Closed"
        hours.openTime != null && hours.closeTime != null -> "${hours.openTime} – ${hours.closeTime}"
        else -> "Hours not available"
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(
                if (striped) Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                else Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
            ),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = day,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
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
