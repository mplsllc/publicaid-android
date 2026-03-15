package org.publicaid.app.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/** Standard API success envelope. */
@JsonClass(generateAdapter = true)
data class ApiResponse<T>(
    val data: T,
    val meta: ApiMeta? = null,
)

@JsonClass(generateAdapter = true)
data class ApiMeta(
    val total: Int? = null,
    val limit: Int? = null,
    val offset: Int? = null,
    @Json(name = "took_ms") val tookMs: Long = 0,
)

/** Standard API error envelope. */
@JsonClass(generateAdapter = true)
data class ApiErrorResponse(
    val error: ApiErrorDetail,
)

@JsonClass(generateAdapter = true)
data class ApiErrorDetail(
    val code: String,
    val message: String,
)

@JsonClass(generateAdapter = true)
data class StatsResponse(
    @Json(name = "total_entities") val totalEntities: Int,
    @Json(name = "total_categories") val totalCategories: Int,
)
