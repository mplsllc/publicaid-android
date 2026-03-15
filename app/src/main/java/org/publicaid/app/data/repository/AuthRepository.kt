package org.publicaid.app.data.repository

import android.content.SharedPreferences
import com.squareup.moshi.Moshi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.publicaid.app.data.api.*
import org.publicaid.app.data.model.AuthState
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepository @Inject constructor(
    private val userApi: dagger.Lazy<UserApi>,
    private val encryptedPrefs: SharedPreferences,
) : TokenProvider {

    private val _authState = MutableStateFlow<AuthState>(AuthState.LoggedOut)
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    init {
        // Restore session from stored token
        val token = encryptedPrefs.getString(KEY_TOKEN, null)
        val userJson = encryptedPrefs.getString(KEY_USER, null)
        if (token != null && userJson != null) {
            try {
                val moshi = Moshi.Builder().build()
                val adapter = moshi.adapter(UserData::class.java)
                val user = adapter.fromJson(userJson)
                if (user != null) {
                    _authState.value = AuthState.LoggedIn(user, token)
                }
            } catch (_: Exception) {
                clearToken()
            }
        }
    }

    // --- TokenProvider implementation ---

    override fun getToken(): String? {
        return encryptedPrefs.getString(KEY_TOKEN, null)
    }

    override fun clearToken() {
        encryptedPrefs.edit()
            .remove(KEY_TOKEN)
            .remove(KEY_USER)
            .apply()
        _authState.value = AuthState.LoggedOut
    }

    // --- Auth operations ---

    suspend fun login(email: String, password: String): Result<UserData> {
        return try {
            val response = userApi.get().login(LoginRequest(email, password))
            if (response.isSuccessful) {
                val body = response.body()
                val data = body?.data
                if (data != null) {
                    saveSession(data.token, data.user)
                    _authState.value = AuthState.LoggedIn(data.user, data.token)
                    Result.success(data.user)
                } else {
                    Result.failure(AuthException(body?.error ?: "unknown_error"))
                }
            } else {
                val errorBody = response.errorBody()?.string()
                val errorCode = parseErrorCode(errorBody)
                Result.failure(AuthException(errorCode))
            }
        } catch (e: Exception) {
            Result.failure(AuthException("network_error"))
        }
    }

    suspend fun register(email: String, password: String, passwordConfirm: String): Result<String> {
        return try {
            val response = userApi.get().register(RegisterRequest(email, password, passwordConfirm))
            if (response.isSuccessful) {
                val message = response.body()?.data?.message ?: "Account created"
                Result.success(message)
            } else {
                val errorBody = response.errorBody()?.string()
                val errorCode = parseErrorCode(errorBody)
                Result.failure(AuthException(errorCode))
            }
        } catch (e: Exception) {
            Result.failure(AuthException("network_error"))
        }
    }

    fun logout() {
        clearToken()
    }

    suspend fun fetchMe(): Result<UserData> {
        return try {
            val response = userApi.get().me()
            if (response.isSuccessful) {
                val user = response.body()?.data
                if (user != null) {
                    // Update stored user data
                    val moshi = Moshi.Builder().build()
                    val adapter = moshi.adapter(UserData::class.java)
                    encryptedPrefs.edit().putString(KEY_USER, adapter.toJson(user)).apply()

                    val token = getToken() ?: return Result.failure(AuthException("unauthorized"))
                    _authState.value = AuthState.LoggedIn(user, token)
                    Result.success(user)
                } else {
                    Result.failure(AuthException("unknown_error"))
                }
            } else {
                Result.failure(AuthException("unauthorized"))
            }
        } catch (e: Exception) {
            Result.failure(AuthException("network_error"))
        }
    }

    private fun saveSession(token: String, user: UserData) {
        val moshi = Moshi.Builder().build()
        val adapter = moshi.adapter(UserData::class.java)
        encryptedPrefs.edit()
            .putString(KEY_TOKEN, token)
            .putString(KEY_USER, adapter.toJson(user))
            .apply()
    }

    private fun parseErrorCode(errorBody: String?): String {
        if (errorBody == null) return "unknown_error"
        return try {
            val moshi = Moshi.Builder().build()
            val adapter = moshi.adapter(ErrorResponse::class.java)
            adapter.fromJson(errorBody)?.error ?: "unknown_error"
        } catch (_: Exception) {
            "unknown_error"
        }
    }

    companion object {
        private const val KEY_TOKEN = "auth_token"
        private const val KEY_USER = "auth_user"
    }
}

class AuthException(val code: String) : Exception(code)

@com.squareup.moshi.JsonClass(generateAdapter = true)
data class ErrorResponse(val error: String?)
