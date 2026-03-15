package org.publicaid.app.ui.screens.bookmarks

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.publicaid.app.ui.components.EmptyState
import org.publicaid.app.ui.components.EntityCard
import org.publicaid.app.ui.components.LoadingIndicator

@Composable
fun BookmarksScreen(
    onEntityClick: (id: String) -> Unit,
    viewModel: BookmarksViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier.fillMaxSize(),
    ) {
        Text(
            text = "Saved Services",
            style = MaterialTheme.typography.headlineLarge,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp),
        )

        when {
            state.isLoading -> LoadingIndicator()
            state.entities.isEmpty() -> EmptyState(
                message = "No saved services yet.\nTap the bookmark icon on any service to save it for offline access.",
            )
            else -> {
                LazyColumn(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.entities, key = { it.id }) { entity ->
                        EntityCard(
                            entity = entity,
                            onClick = { onEntityClick(entity.id) },
                        )
                    }
                }
            }
        }
    }
}
