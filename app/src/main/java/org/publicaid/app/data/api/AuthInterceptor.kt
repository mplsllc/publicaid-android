package org.publicaid.app.data.api

import okhttp3.Interceptor
import okhttp3.Response
import org.publicaid.app.BuildConfig
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Adds the API key as a Bearer token to every request.
 * The key is a free-tier mobile-app key, rate-limited and rotatable.
 */
@Singleton
class AuthInterceptor @Inject constructor() : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val apiKey = BuildConfig.API_KEY
        if (apiKey.isBlank()) return chain.proceed(request)

        val authenticated = request.newBuilder()
            .header("Authorization", "Bearer $apiKey")
            .header("User-Agent", "Publicaid-Android/${BuildConfig.VERSION_NAME}")
            .build()
        return chain.proceed(authenticated)
    }
}
