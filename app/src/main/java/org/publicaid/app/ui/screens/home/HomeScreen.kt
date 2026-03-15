package org.publicaid.app.ui.screens.home

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.publicaid.app.data.model.Category
import org.publicaid.app.ui.components.ErrorState
import org.publicaid.app.ui.components.LoadingIndicator
import org.publicaid.app.ui.components.PublicaidSearchBar

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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onSearch: (query: String, lat: Double?, lng: Double?) -> Unit,
    onCategoryClick: (slug: String, lat: Double?, lng: Double?) -> Unit,
    onNavigateToBookmarks: () -> Unit,
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "Publicaid",
                        style = MaterialTheme.typography.headlineMedium,
                    )
                },
                actions = {
                    IconButton(onClick = onNavigateToBookmarks) {
                        Icon(Icons.Default.Bookmark, contentDescription = "Saved")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                    actionIconContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            // Search bar
            Surface(
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                ) {
                    Text(
                        text = "Find help near you",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.9f),
                    )
                    Spacer(Modifier.height(8.dp))
                    PublicaidSearchBar(
                        query = query,
                        onQueryChange = { query = it },
                        onSearch = {
                            onSearch(query, state.location?.latitude, state.location?.longitude)
                        },
                    )
                    // Location indicator
                    if (state.locationGranted && state.location != null) {
                        Spacer(Modifier.height(4.dp))
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Icon(
                                Icons.Default.MyLocation,
                                contentDescription = null,
                                modifier = Modifier.size(12.dp),
                                tint = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.7f),
                            )
                            Text(
                                text = "Using your location for nearby results",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.7f),
                            )
                        }
                    }
                }
            }

            // Category grid
            when {
                state.isLoading -> LoadingIndicator()
                state.error != null -> ErrorState(
                    message = state.error!!,
                    onRetry = { viewModel.loadCategories() },
                )
                else -> {
                    Text(
                        text = "Browse by category",
                        style = MaterialTheme.typography.titleMedium,
                        modifier = Modifier.padding(16.dp),
                    )
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(3),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.categories) { category ->
                            CategoryCard(
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
            }
        }
    }
}

@Composable
private fun CategoryCard(
    category: Category,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant,
        ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Icon(
                imageVector = categoryIcons[category.slug] ?: Icons.Default.Category,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(32.dp),
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = category.name,
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
