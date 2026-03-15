package org.publicaid.app.data.api

/**
 * Provides and manages the user's auth token.
 * Implemented by AuthRepository to break the circular DI:
 * AuthRepository -> UserApi -> Retrofit -> OkHttpClient -> AuthInterceptor -> TokenProvider -> AuthRepository
 */
interface TokenProvider {
    fun getToken(): String?
    fun clearToken()
}
