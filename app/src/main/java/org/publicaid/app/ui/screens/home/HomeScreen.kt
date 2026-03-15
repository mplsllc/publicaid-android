package org.publicaid.app.ui.screens.home

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.publicaid.app.R
import org.publicaid.app.data.model.Category
import org.publicaid.app.ui.components.ErrorState
import org.publicaid.app.ui.components.LoadingIndicator
import org.publicaid.app.ui.components.PublicaidSearchBar
import org.publicaid.app.ui.theme.*

private val categoryIcons = mapOf(
    "food" to Icons.Default.Restaurant,
    "housing" to Icons.Default.Home,
    "health" to Icons.Default.LocalHospital,
    "mental-health" to Icons.Default.Psychology,
    "substance-use" to Icons.Default.Healing,
    "education" to Icons.Default.School,
    "employment" to Icons.Default.Work,
    "legal" to Icons.Default.Gavel,
    "transportation" to Icons.Default.DirectionsBus,
    "utilities" to Icons.Default.ElectricBolt,
    "clothing" to Icons.Default.Checkroom,
    "disabilities" to Icons.Default.Accessible,
    "veterans" to Icons.Default.MilitaryTech,
    "seniors" to Icons.Default.Elderly,
    "youth" to Icons.Default.ChildCare,
)

@Composable
fun HomeScreen(
    onSearch: (query: String, lat: Double?, lng: Double?) -> Unit,
    onCategoryClick: (slug: String, lat: Double?, lng: Double?) -> Unit,
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val colors = LocalExtendedColors.current
    var query by remember { mutableStateOf("") }

    val locationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) viewModel.onLocationPermissionGranted()
    }

    LaunchedEffect(Unit) {
        viewModel.checkLocation()
        if (!state.locationGranted) {
            locationLauncher.launch(Manifest.permission.ACCESS_COARSE_LOCATION)
        } else {
            viewModel.refreshLocation()
        }
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
    ) {
        // Hero section with gradient
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(NavyBlue, BrightBlue),
                        )
                    ),
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 24.dp),
                ) {
                    // Logo
                    androidx.compose.foundation.Image(
                        painter = painterResource(R.drawable.logo_light),
                        contentDescription = "Publicaid",
                        modifier = Modifier.height(28.dp),
                        contentScale = ContentScale.FillHeight,
                    )

                    Spacer(Modifier.height(24.dp))

                    Text(
                        text = "Find help near you",
                        style = MaterialTheme.typography.displayLarge,
                        color = Color.White,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "Search thousands of verified social services",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.8f),
                    )

                    // Location indicator
                    if (state.locationGranted && state.location != null) {
                        Spacer(Modifier.height(8.dp))
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Icon(
                                Icons.Default.MyLocation,
                                contentDescription = null,
                                modifier = Modifier.size(12.dp),
                                tint = Color.White.copy(alpha = 0.7f),
                            )
                            Text(
                                text = "Using your location for nearby results",
                                style = MaterialTheme.typography.labelSmall,
                                color = Color.White.copy(alpha = 0.7f),
                            )
                        }
                    }

                    Spacer(Modifier.height(32.dp))
                }
            }
        }

        // Overlapping search card
        item {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .offset(y = (-28).dp),
                shape = RoundedCornerShape(12.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            ) {
                PublicaidSearchBar(
                    query = query,
                    onQueryChange = { query = it },
                    onSearch = {
                        onSearch(query, state.location?.latitude, state.location?.longitude)
                    },
                    modifier = Modifier.padding(12.dp),
                )
            }
        }

        // Category section
        item {
            Text(
                text = "Browse by category",
                style = MaterialTheme.typography.headlineLarge,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 12.dp),
            )
        }

        when {
            state.isLoading -> item { LoadingIndicator(Modifier.height(200.dp)) }
            state.error != null -> item {
                ErrorState(
                    message = state.error!!,
                    onRetry = { viewModel.loadCategories() },
                    modifier = Modifier.height(200.dp),
                )
            }
            else -> {
                items(state.categories) { category ->
                    CategoryRow(
                        category = category,
                        onClick = {
                            onCategoryClick(
                                category.slug,
                                state.location?.latitude,
                                state.location?.longitude,
                            )
                        },
                    )
                }
            }
        }

        // Bottom spacing
        item { Spacer(Modifier.height(16.dp)) }
    }
}

@Composable
private fun CategoryRow(
    category: Category,
    onClick: () -> Unit,
) {
    val colors = LocalExtendedColors.current

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        border = BorderStroke(1.dp, colors.cardBorder),
        shape = RoundedCornerShape(12.dp),
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Icon box
            Surface(
                modifier = Modifier.size(44.dp),
                color = MaterialTheme.colorScheme.background,
                shape = RoundedCornerShape(8.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = categoryIcons[category.slug] ?: Icons.Default.Category,
                        contentDescription = null,
                        tint = colors.brightBlue,
                        modifier = Modifier.size(24.dp),
                    )
                }
            }

            // Name + description
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = category.name,
                    style = MaterialTheme.typography.titleMedium,
                    color = colors.navyBlue,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                category.description?.let { desc ->
                    Text(
                        text = desc,
                        style = MaterialTheme.typography.bodySmall,
                        color = colors.grayText,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }

            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = colors.mediumGray,
            )
        }
    }
}
