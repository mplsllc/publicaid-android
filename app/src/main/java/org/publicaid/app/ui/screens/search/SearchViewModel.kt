package org.publicaid.app.ui.screens.search

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.publicaid.app.data.model.Category
import org.publicaid.app.data.model.Entity
import org.publicaid.app.data.repository.CategoryRepository
import org.publicaid.app.data.repository.SearchRepository
import org.publicaid.app.ui.components.SearchFilters
import javax.inject.Inject

data class SearchUiState(
    val query: String = "",
    val results: List<Entity> = emptyList(),
    val total: Int = 0,
    val isLoading: Boolean = false,
    val error: String? = null,
    val filters: SearchFilters = SearchFilters(),
    val categories: List<Category> = emptyList(),
    val states: List<String> = emptyList(),
    val lat: Double? = null,
    val lng: Double? = null,
    val hasMore: Boolean = false,
    val offset: Int = 0,
)

@HiltViewModel
class SearchViewModel @Inject constructor(
    private val searchRepository: SearchRepository,
    private val categoryRepository: CategoryRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val _uiState = MutableStateFlow(SearchUiState())
    val uiState: StateFlow<SearchUiState> = _uiState.asStateFlow()

    init {
        // Read initial params from navigation args
        val query = savedStateHandle.get<String>("query") ?: ""
        val category = savedStateHandle.get<String>("category")
        val lat = savedStateHandle.get<String>("lat")?.toDoubleOrNull()
        val lng = savedStateHandle.get<String>("lng")?.toDoubleOrNull()

        _uiState.value = _uiState.value.copy(
            query = query,
            lat = lat,
            lng = lng,
            filters = SearchFilters(category = category),
        )

        loadFilterOptions()
        if (query.isNotBlank() || category != null) {
            search()
        }
    }

    private fun loadFilterOptions() {
        viewModelScope.launch {
            categoryRepository.getCategories().onSuccess { cats ->
                _uiState.value = _uiState.value.copy(categories = cats)
            }
            categoryRepository.getFilters().onSuccess { filters ->
                _uiState.value = _uiState.value.copy(states = filters.states)
            }
        }
    }

    fun updateQuery(query: String) {
        _uiState.value = _uiState.value.copy(query = query)
    }

    fun updateFilters(filters: SearchFilters) {
        _uiState.value = _uiState.value.copy(filters = filters, offset = 0, results = emptyList())
        search()
    }

    fun search() {
        val state = _uiState.value
        viewModelScope.launch {
            _uiState.value = state.copy(isLoading = true, error = null, offset = 0)
            val sort = if (state.lat != null && state.lng != null) "distance" else "relevance"
            searchRepository.search(
                query = state.query.ifBlank { null },
                state = state.filters.state,
                category = state.filters.category,
                language = state.filters.language,
                paymentType = state.filters.paymentType,
                population = state.filters.population,
                accessibility = state.filters.accessibility,
                sort = sort,
                lat = state.lat,
                lng = state.lng,
                limit = PAGE_SIZE,
                offset = 0,
            ).onSuccess { response ->
                _uiState.value = _uiState.value.copy(
                    results = response.data,
                    total = response.meta?.total ?: response.data.size,
                    isLoading = false,
                    hasMore = response.data.size >= PAGE_SIZE,
                    offset = response.data.size,
                )
            }.onFailure { e ->
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Search failed",
                )
            }
        }
    }

    fun loadMore() {
        val state = _uiState.value
        if (state.isLoading || !state.hasMore) return
        viewModelScope.launch {
            _uiState.value = state.copy(isLoading = true)
            val sort = if (state.lat != null && state.lng != null) "distance" else "relevance"
            searchRepository.search(
                query = state.query.ifBlank { null },
                state = state.filters.state,
                category = state.filters.category,
                sort = sort,
                lat = state.lat,
                lng = state.lng,
                limit = PAGE_SIZE,
                offset = state.offset,
            ).onSuccess { response ->
                _uiState.value = _uiState.value.copy(
                    results = state.results + response.data,
                    isLoading = false,
                    hasMore = response.data.size >= PAGE_SIZE,
                    offset = state.offset + response.data.size,
                )
            }.onFailure {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }

    companion object {
        private const val PAGE_SIZE = 10
    }
}
