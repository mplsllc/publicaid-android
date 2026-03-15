package org.publicaid.app.ui.screens.categories

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.publicaid.app.data.model.Category
import org.publicaid.app.ui.components.ErrorState
import org.publicaid.app.ui.components.LoadingIndicator

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoriesScreen(
    onCategoryClick: (slug: String) -> Unit,
    onBack: () -> Unit,
    viewModel: CategoriesViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Categories") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        when {
            state.isLoading -> LoadingIndicator(Modifier.padding(padding))
            state.error != null -> ErrorState(
                message = state.error!!,
                onRetry = { viewModel.load() },
                modifier = Modifier.padding(padding),
            )
            else -> {
                // Flatten categories + children into a single list
                val flatList = state.categories.flatMap { cat ->
                    listOf(cat to false) + cat.children.map { it to true }
                }
                LazyColumn(
                    modifier = Modifier.padding(padding),
                    contentPadding = PaddingValues(vertical = 8.dp),
                ) {
                    items(flatList, key = { it.first.id }) { (category, isChild) ->
                        CategoryRow(
                            category = category,
                            onClick = { onCategoryClick(category.slug) },
                            indent = isChild,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CategoryRow(
    category: Category,
    onClick: () -> Unit,
    indent: Boolean = false,
) {
    ListItem(
        headlineContent = {
            Text(
                text = category.name,
                style = if (indent) MaterialTheme.typography.bodyMedium
                else MaterialTheme.typography.titleMedium,
            )
        },
        supportingContent = category.description?.let {
            { Text(it, maxLines = 1, style = MaterialTheme.typography.bodySmall) }
        },
        trailingContent = {
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        },
        modifier = Modifier
            .clickable(onClick = onClick)
            .then(if (indent) Modifier.padding(start = 24.dp) else Modifier),
    )
}
