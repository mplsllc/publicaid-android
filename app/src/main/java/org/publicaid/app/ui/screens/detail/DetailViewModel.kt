package org.publicaid.app.ui.screens.detail

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import org.publicaid.app.data.model.Entity
import org.publicaid.app.data.model.EntityHours
import org.publicaid.app.data.model.EntityService
import org.publicaid.app.data.repository.BookmarkRepository
import org.publicaid.app.data.repository.EntityRepository
import javax.inject.Inject

data class DetailUiState(
    val entity: Entity? = null,
    val services: List<EntityService> = emptyList(),
    val hours: List<EntityHours> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
)

@HiltViewModel
class DetailViewModel @Inject constructor(
    private val entityRepository: EntityRepository,
    private val bookmarkRepository: BookmarkRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val entityId: String = savedStateHandle.get<String>("entityId") ?: ""

    private val _uiState = MutableStateFlow(DetailUiState())
    val uiState: StateFlow<DetailUiState> = _uiState.asStateFlow()

    val isBookmarked: StateFlow<Boolean> = bookmarkRepository.isBookmarked(entityId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    init {
        loadEntity()
    }

    fun loadEntity() {
        viewModelScope.launch {
            _uiState.value = DetailUiState(isLoading = true)
            entityRepository.getEntity(entityId)
                .onSuccess { entity ->
                    _uiState.value = _uiState.value.copy(entity = entity, isLoading = false)
                    // Load services and hours in parallel
                    launch {
                        entityRepository.getEntityServices(entityId).onSuccess { services ->
                            _uiState.value = _uiState.value.copy(services = services)
                        }
                    }
                    launch {
                        entityRepository.getEntityHours(entityId).onSuccess { hours ->
                            _uiState.value = _uiState.value.copy(hours = hours)
                        }
                    }
                }
                .onFailure { e ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = e.message ?: "Failed to load",
                    )
                }
        }
    }

    fun toggleBookmark() {
        val entity = _uiState.value.entity ?: return
        viewModelScope.launch {
            bookmarkRepository.toggle(entity)
        }
    }
}
