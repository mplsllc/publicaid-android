package org.publicaid.app.ui.screens.home

import android.location.Location
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.publicaid.app.data.model.Category
import org.publicaid.app.data.repository.CategoryRepository
import org.publicaid.app.util.LocationHelper
import javax.inject.Inject

data class HomeUiState(
    val categories: List<Category> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
    val location: Location? = null,
    val locationGranted: Boolean = false,
)

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val categoryRepository: CategoryRepository,
    private val locationHelper: LocationHelper,
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        loadCategories()
        checkLocation()
    }

    fun loadCategories() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            categoryRepository.getCategories()
                .onSuccess { categories ->
                    _uiState.value = _uiState.value.copy(
                        categories = categories,
                        isLoading = false,
                    )
                }
                .onFailure { e ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = e.message ?: "Failed to load categories",
                    )
                }
        }
    }

    fun checkLocation() {
        _uiState.value = _uiState.value.copy(locationGranted = locationHelper.hasPermission())
    }

    fun onLocationPermissionGranted() {
        _uiState.value = _uiState.value.copy(locationGranted = true)
        viewModelScope.launch {
            val location = locationHelper.getLastLocation()
                ?: locationHelper.getCurrentLocation()
            _uiState.value = _uiState.value.copy(location = location)
        }
    }

    fun refreshLocation() {
        viewModelScope.launch {
            val location = locationHelper.getCurrentLocation()
                ?: locationHelper.getLastLocation()
            _uiState.value = _uiState.value.copy(location = location)
        }
    }
}
