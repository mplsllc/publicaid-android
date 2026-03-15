package org.publicaid.app.ui.screens.bookmarks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.publicaid.app.data.model.Entity
import org.publicaid.app.data.repository.BookmarkRepository
import javax.inject.Inject

data class BookmarksUiState(
    val entities: List<Entity> = emptyList(),
    val isLoading: Boolean = true,
)

@HiltViewModel
class BookmarksViewModel @Inject constructor(
    private val bookmarkRepository: BookmarkRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(BookmarksUiState())
    val uiState: StateFlow<BookmarksUiState> = _uiState.asStateFlow()

    init {
        loadBookmarks()
        // Re-load when bookmarks change
        viewModelScope.launch {
            bookmarkRepository.observeBookmarks().collect {
                loadBookmarks()
            }
        }
    }

    private fun loadBookmarks() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            val entities = bookmarkRepository.getBookmarkedEntities()
            _uiState.value = BookmarksUiState(entities = entities, isLoading = false)
        }
    }
}
