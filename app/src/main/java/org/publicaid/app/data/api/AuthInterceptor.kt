package org.publicaid.app.data.api

import okhttp3.Interceptor
import okhttp3.Response
import org.publicaid.app.BuildConfig
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Dual-mode auth interceptor:
 * - If user is logged in (TokenProvider has token), sends user JWT
 * - Otherwise, sends API key
 *
 * Also handles 401 responses by clearing the stored token.
 */
@Singleton
class AuthInterceptor @Inject constructor(
    private val tokenProvider: TokenProvider,
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()

        // Determine which token to use
        val userToken = tokenProvider.getToken()
        val token = userToken ?: BuildConfig.API_KEY

        val authenticated = if (token.isNotBlank()) {
            request.newBuilder()
                .header("Authorization", "Bearer $token")
                .header("User-Agent", "Publicaid-Android/${BuildConfig.VERSION_NAME}")
                .build()
        } else {
            request.newBuilder()
                .header("User-Agent", "Publicaid-Android/${BuildConfig.VERSION_NAME}")
                .build()
        }

        val response = chain.proceed(authenticated)

        // If we sent a user token and got 401, clear it (expired/revoked)
        if (response.code == 401 && userToken != null) {
            tokenProvider.clearToken()
        }

        return response
    }
}
