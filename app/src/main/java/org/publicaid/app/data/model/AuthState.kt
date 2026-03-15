package org.publicaid.app.data.model

import org.publicaid.app.data.api.UserData

sealed class AuthState {
    data object LoggedOut : AuthState()
    data class LoggedIn(val user: UserData, val token: String) : AuthState()
}
