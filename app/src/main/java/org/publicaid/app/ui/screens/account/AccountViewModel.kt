package org.publicaid.app.ui.screens.account

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.publicaid.app.data.model.AuthState
import org.publicaid.app.data.repository.AuthException
import org.publicaid.app.data.repository.AuthRepository
import org.publicaid.app.data.repository.BookmarkRepository
import javax.inject.Inject

data class LoginUiState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val success: Boolean = false,
)

data class RegisterUiState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val successMessage: String? = null,
)

@HiltViewModel
class AccountViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val bookmarkRepository: BookmarkRepository,
) : ViewModel() {

    val authState: StateFlow<AuthState> = authRepository.authState

    private val _loginState = MutableStateFlow(LoginUiState())
    val loginState: StateFlow<LoginUiState> = _loginState.asStateFlow()

    private val _registerState = MutableStateFlow(RegisterUiState())
    val registerState: StateFlow<RegisterUiState> = _registerState.asStateFlow()

    fun login(email: String, password: String) {
        viewModelScope.launch {
            _loginState.value = LoginUiState(isLoading = true)
            val result = authRepository.login(email, password)
            result.fold(
                onSuccess = {
                    // Sync bookmarks with server after login
                    viewModelScope.launch {
                        try { bookmarkRepository.syncOnLogin() } catch (_: Exception) {}
                    }
                    _loginState.value = LoginUiState(success = true)
                },
                onFailure = { e ->
                    val errorMessage = when ((e as? AuthException)?.code) {
                        "invalid_credentials" -> "Invalid email or password"
                        "email_not_verified" -> "Please verify your email before signing in. Check your inbox for a verification link."
                        "account_suspended" -> "Your account has been suspended"
                        "network_error" -> "Unable to connect. Check your internet connection."
                        "validation_error" -> "Please check your email and password"
                        else -> "Something went wrong. Please try again."
                    }
                    _loginState.value = LoginUiState(error = errorMessage)
                },
            )
        }
    }

    fun register(email: String, password: String, passwordConfirm: String) {
        viewModelScope.launch {
            _registerState.value = RegisterUiState(isLoading = true)
            val result = authRepository.register(email, password, passwordConfirm)
            result.fold(
                onSuccess = { message ->
                    _registerState.value = RegisterUiState(successMessage = message)
                },
                onFailure = { e ->
                    val errorMessage = when ((e as? AuthException)?.code) {
                        "email_already_registered" -> "An account with this email already exists"
                        "passwords_do_not_match" -> "Passwords do not match"
                        "network_error" -> "Unable to connect. Check your internet connection."
                        "validation_error" -> "Please check your input"
                        else -> "Something went wrong. Please try again."
                    }
                    _registerState.value = RegisterUiState(error = errorMessage)
                },
            )
        }
    }

    fun logout() {
        authRepository.logout()
    }

    fun clearLoginError() {
        _loginState.value = _loginState.value.copy(error = null)
    }

    fun clearRegisterError() {
        _registerState.value = _registerState.value.copy(error = null)
    }
}
