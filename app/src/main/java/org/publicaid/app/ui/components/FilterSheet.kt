package org.publicaid.app.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import org.publicaid.app.data.model.Category
import org.publicaid.app.ui.theme.LocalExtendedColors

data class SearchFilters(
    val state: String? = null,
    val category: String? = null,
    val language: String? = null,
    val paymentType: String? = null,
    val population: String? = null,
    val accessibility: String? = null,
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun FilterSheet(
    filters: SearchFilters,
    categories: List<Category>,
    states: List<String>,
    onFiltersChanged: (SearchFilters) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = LocalExtendedColors.current

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        modifier = modifier,
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                text = "Filters",
                style = MaterialTheme.typography.headlineSmall,
            )

            // Category chips
            if (categories.isNotEmpty()) {
                Text(
                    "Category",
                    style = MaterialTheme.typography.labelLarge,
                    color = colors.grayText,
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    categories.forEach { cat ->
                        val selected = filters.category == cat.slug
                        FilterChip(
                            selected = selected,
                            onClick = {
                                val newCat = if (selected) null else cat.slug
                                onFiltersChanged(filters.copy(category = newCat))
                            },
                            label = { Text(cat.name) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = colors.brightBlue,
                                selectedLabelColor = Color.White,
                                containerColor = colors.tagBg,
                                labelColor = colors.brightBlue,
                            ),
                        )
                    }
                }
            }

            // State chips (top 20 most common)
            if (states.isNotEmpty()) {
                Text(
                    "State",
                    style = MaterialTheme.typography.labelLarge,
                    color = colors.grayText,
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    states.take(20).forEach { st ->
                        val selected = filters.state == st
                        FilterChip(
                            selected = selected,
                            onClick = {
                                val newState = if (selected) null else st
                                onFiltersChanged(filters.copy(state = newState))
                            },
                            label = { Text(st) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = colors.brightBlue,
                                selectedLabelColor = Color.White,
                                containerColor = colors.tagBg,
                                labelColor = colors.brightBlue,
                            ),
                        )
                    }
                }
            }

            // Clear all
            if (filters != SearchFilters()) {
                TextButton(
                    onClick = { onFiltersChanged(SearchFilters()) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Clear all filters")
                }
            }
        }
    }
}
