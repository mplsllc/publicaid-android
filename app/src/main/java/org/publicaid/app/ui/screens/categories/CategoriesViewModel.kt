package org.publicaid.app.ui.screens.categories

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.publicaid.app.data.model.Category
import org.publicaid.app.data.repository.CategoryRepository
import javax.inject.Inject

data class CategoriesUiState(
    val categories: List<Category> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
)

@HiltViewModel
class CategoriesViewModel @Inject constructor(
    private val categoryRepository: CategoryRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(CategoriesUiState())
    val uiState: StateFlow<CategoriesUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.value = CategoriesUiState(isLoading = true)
            categoryRepository.getCategories()
                .onSuccess { cats ->
                    _uiState.value = CategoriesUiState(categories = cats, isLoading = false)
                }
                .onFailure { e ->
                    _uiState.value = CategoriesUiState(
                        isLoading = false,
                        error = e.message ?: "Failed to load categories",
                    )
                }
        }
    }
}
