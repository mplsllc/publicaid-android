package org.publicaid.app.data.api

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import retrofit2.Response
import retrofit2.http.*

// --- Request types ---

@JsonClass(generateAdapter = true)
data class LoginRequest(
    val email: String,
    val password: String,
)

@JsonClass(generateAdapter = true)
data class RegisterRequest(
    val email: String,
    val password: String,
    @Json(name = "password_confirm") val passwordConfirm: String,
)

// --- Response types ---

@JsonClass(generateAdapter = true)
data class ApiDataResponse<T>(
    val data: T? = null,
    val error: String? = null,
)

@JsonClass(generateAdapter = true)
data class LoginResponseData(
    val token: String,
    val user: UserData,
)

@JsonClass(generateAdapter = true)
data class UserData(
    val id: String,
    val email: String,
    val username: String? = null,
    @Json(name = "display_name") val displayName: String? = null,
    @Json(name = "avatar_url") val avatarUrl: String? = null,
    val city: String? = null,
    val state: String? = null,
    @Json(name = "is_public") val isPublic: Boolean = false,
)

@JsonClass(generateAdapter = true)
data class MessageData(
    val message: String,
)

@JsonClass(generateAdapter = true)
data class BookmarkItemData(
    @Json(name = "entity_id") val entityId: String,
    val name: String,
    val slug: String,
    val city: String? = null,
    val state: String? = null,
    val notes: String? = null,
    @Json(name = "checkin_count") val checkinCount: Int = 0,
)

@JsonClass(generateAdapter = true)
data class ToggleData(
    val saved: Boolean? = null,
    val supported: Boolean? = null,
)

@JsonClass(generateAdapter = true)
data class SupportedEntityData(
    val id: String,
    val name: String,
    val slug: String,
    val city: String? = null,
    val state: String? = null,
)

// --- API Interface ---

interface UserApi {
    @POST("api/user/login")
    suspend fun login(@Body request: LoginRequest): Response<ApiDataResponse<LoginResponseData>>

    @POST("api/user/register")
    suspend fun register(@Body request: RegisterRequest): Response<ApiDataResponse<MessageData>>

    @GET("api/user/me")
    suspend fun me(): Response<ApiDataResponse<UserData>>

    @GET("api/user/bookmarks")
    suspend fun listBookmarks(): Response<ApiDataResponse<List<BookmarkItemData>>>

    @POST("api/user/bookmarks/{entity_id}")
    suspend fun toggleBookmark(@Path("entity_id") entityId: String): Response<ApiDataResponse<ToggleData>>

    @POST("api/user/support/{entity_id}")
    suspend fun toggleSupport(@Path("entity_id") entityId: String): Response<ApiDataResponse<ToggleData>>

    @GET("api/user/support")
    suspend fun listSupported(): Response<ApiDataResponse<List<SupportedEntityData>>>
}
