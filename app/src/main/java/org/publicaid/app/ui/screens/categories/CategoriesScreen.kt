package org.publicaid.app.ui.screens.categories

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Category
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.publicaid.app.data.model.Category
import org.publicaid.app.ui.components.ErrorState
import org.publicaid.app.ui.components.LoadingIndicator
import org.publicaid.app.ui.theme.LocalExtendedColors

@Composable
fun CategoriesScreen(
    onCategoryClick: (slug: String) -> Unit,
    viewModel: CategoriesViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val colors = LocalExtendedColors.current

    Column(
        modifier = Modifier.fillMaxSize(),
    ) {
        Text(
            text = "Categories",
            style = MaterialTheme.typography.headlineLarge,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp),
        )

        when {
            state.isLoading -> LoadingIndicator()
            state.error != null -> ErrorState(
                message = state.error!!,
                onRetry = { viewModel.load() },
            )
            else -> {
                // Flatten categories + children into a single list
                val flatList = state.categories.flatMap { cat ->
                    listOf(cat to false) + cat.children.map { it to true }
                }
                LazyColumn(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(flatList, key = { it.first.id }) { (category, isChild) ->
                        CategoryRow(
                            category = category,
                            onClick = { onCategoryClick(category.slug) },
                            isChild = isChild,
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
    isChild: Boolean = false,
) {
    val colors = LocalExtendedColors.current

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (isChild) Modifier.padding(start = 24.dp) else Modifier)
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        border = BorderStroke(
            width = if (isChild) 1.dp else 1.5.dp,
            color = colors.cardBorder,
        ),
        shape = RoundedCornerShape(12.dp),
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Emoji/icon box
            Surface(
                modifier = Modifier.size(if (isChild) 36.dp else 44.dp),
                color = MaterialTheme.colorScheme.background,
                shape = RoundedCornerShape(8.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Default.Category,
                        contentDescription = null,
                        tint = if (isChild) colors.grayText else colors.brightBlue,
                        modifier = Modifier.size(if (isChild) 18.dp else 22.dp),
                    )
                }
            }

            // Name + description
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = category.name,
                    style = if (isChild) MaterialTheme.typography.bodyMedium
                    else MaterialTheme.typography.titleMedium,
                    fontWeight = if (isChild) FontWeight.Normal else FontWeight.SemiBold,
                    color = colors.navyBlue,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (!isChild) {
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
            }

            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = colors.mediumGray,
                modifier = Modifier.size(20.dp),
            )
        }
    }
}
