package org.publicaid.app.ui.screens.search

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.publicaid.app.ui.components.*
import org.publicaid.app.ui.theme.LocalExtendedColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(
    onEntityClick: (id: String) -> Unit,
    onBack: () -> Unit,
    viewModel: SearchViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val colors = LocalExtendedColors.current
    var showFilters by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()

    // Load more when near the end
    val shouldLoadMore by remember {
        derivedStateOf {
            val lastVisibleItem = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            lastVisibleItem >= state.results.size - 3 && state.hasMore && !state.isLoading
        }
    }
    LaunchedEffect(shouldLoadMore) {
        if (shouldLoadMore) viewModel.loadMore()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    PublicaidSearchBar(
                        query = state.query,
                        onQueryChange = { viewModel.updateQuery(it) },
                        onSearch = { viewModel.search() },
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { showFilters = true }) {
                        Icon(Icons.Default.Tune, contentDescription = "Filters")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            // Active filter chips
            if (state.filters != SearchFilters()) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    state.filters.category?.let { cat ->
                        Surface(
                            color = colors.tagBg,
                            shape = RoundedCornerShape(50),
                        ) {
                            Row(
                                modifier = Modifier.padding(start = 12.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                            ) {
                                Text(cat, style = MaterialTheme.typography.labelSmall, color = colors.brightBlue)
                                IconButton(
                                    onClick = { viewModel.updateFilters(state.filters.copy(category = null)) },
                                    modifier = Modifier.size(20.dp),
                                ) {
                                    Icon(
                                        Icons.Default.Close,
                                        contentDescription = "Remove",
                                        modifier = Modifier.size(14.dp),
                                        tint = colors.brightBlue,
                                    )
                                }
                            }
                        }
                    }
                    state.filters.state?.let { st ->
                        Surface(
                            color = colors.tagBg,
                            shape = RoundedCornerShape(50),
                        ) {
                            Row(
                                modifier = Modifier.padding(start = 12.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                            ) {
                                Text(st, style = MaterialTheme.typography.labelSmall, color = colors.brightBlue)
                                IconButton(
                                    onClick = { viewModel.updateFilters(state.filters.copy(state = null)) },
                                    modifier = Modifier.size(20.dp),
                                ) {
                                    Icon(
                                        Icons.Default.Close,
                                        contentDescription = "Remove",
                                        modifier = Modifier.size(14.dp),
                                        tint = colors.brightBlue,
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Results count
            if (state.results.isNotEmpty()) {
                Text(
                    text = "${state.total} results",
                    style = MaterialTheme.typography.labelMedium,
                    color = colors.grayText,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                )
            }

            // Results list
            when {
                state.isLoading && state.results.isEmpty() -> LoadingIndicator()
                state.error != null && state.results.isEmpty() -> ErrorState(
                    message = state.error!!,
                    onRetry = { viewModel.search() },
                )
                state.results.isEmpty() && !state.isLoading -> EmptyState()
                else -> {
                    LazyColumn(
                        state = listState,
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.results, key = { it.id }) { entity ->
                            EntityCard(
                                entity = entity,
                                onClick = { onEntityClick(entity.id) },
                            )
                        }
                        if (state.isLoading && state.results.isNotEmpty()) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                    contentAlignment = androidx.compose.ui.Alignment.Center,
                                ) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(24.dp),
                                        color = colors.brightBlue,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showFilters) {
        FilterSheet(
            filters = state.filters,
            categories = state.categories,
            states = state.states,
            onFiltersChanged = { viewModel.updateFilters(it) },
            onDismiss = { showFilters = false },
        )
    }
}
