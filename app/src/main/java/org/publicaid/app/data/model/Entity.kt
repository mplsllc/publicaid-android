package org.publicaid.app.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/** Mirrors APIEntityResponse from the server. */
@JsonClass(generateAdapter = true)
data class Entity(
    val id: String,
    val name: String,
    val slug: String,
    val description: String? = null,
    val phone: String? = null,
    val website: String? = null,
    @Json(name = "address_line1") val addressLine1: String? = null,
    @Json(name = "address_line2") val addressLine2: String? = null,
    val city: String? = null,
    val state: String? = null,
    val zip: String? = null,
    val country: String = "United States",
    val lat: Double? = null,
    val lng: Double? = null,
    val languages: List<String> = emptyList(),
    val accessibility: List<String> = emptyList(),
    @Json(name = "alternate_name") val alternateName: String? = null,
    @Json(name = "intake_phone") val intakePhone: String? = null,
    @Json(name = "payment_types") val paymentTypes: List<String> = emptyList(),
    @Json(name = "populations_served") val populationsServed: List<String> = emptyList(),
    @Json(name = "age_groups") val ageGroups: List<String> = emptyList(),
    @Json(name = "service_settings") val serviceSettings: List<String> = emptyList(),
    val accreditations: List<String> = emptyList(),
    val categories: List<Category> = emptyList(),
    @Json(name = "distance_miles") val distanceMiles: Double? = null,
    @Json(name = "updated_at") val updatedAt: String = "",
    @Json(name = "data_quality") val dataQuality: DataQuality? = null,
) {
    /** Formatted single-line address. */
    val addressLine: String
        get() = listOfNotNull(addressLine1, city, state?.let { "$it $zip" })
            .joinToString(", ")
}

@JsonClass(generateAdapter = true)
data class DataQuality(
    @Json(name = "freshness_score") val freshnessScore: Double = 0.0,
    @Json(name = "source_count") val sourceCount: Int = 0,
    @Json(name = "is_verified") val isVerified: Boolean = false,
    @Json(name = "last_verified_at") val lastVerifiedAt: String? = null,
    @Json(name = "updated_at") val updatedAt: String = "",
    @Json(name = "community_flags") val communityFlags: Int = 0,
    @Json(name = "has_active_flags") val hasActiveFlags: Boolean = false,
)

@JsonClass(generateAdapter = true)
data class Category(
    val id: String,
    val name: String,
    val slug: String,
    @Json(name = "parent_id") val parentId: String? = null,
    val description: String? = null,
    val icon: String? = null,
    @Json(name = "sort_order") val sortOrder: Int = 0,
    val children: List<Category> = emptyList(),
)

@JsonClass(generateAdapter = true)
data class EntityHours(
    val id: String,
    @Json(name = "entity_id") val entityId: String,
    @Json(name = "day_of_week") val dayOfWeek: Int,
    @Json(name = "open_time") val openTime: String? = null,
    @Json(name = "close_time") val closeTime: String? = null,
    @Json(name = "is_closed") val isClosed: Boolean = false,
    val notes: String? = null,
)

@JsonClass(generateAdapter = true)
data class EntityService(
    val id: String,
    @Json(name = "entity_id") val entityId: String,
    val name: String,
    val description: String? = null,
    val eligibility: String? = null,
    val fees: String? = null,
    @Json(name = "sort_order") val sortOrder: Int = 0,
)

@JsonClass(generateAdapter = true)
data class FilterValues(
    val languages: List<String> = emptyList(),
    @Json(name = "payment_types") val paymentTypes: List<String> = emptyList(),
    val populations: List<String> = emptyList(),
    val accessibility: List<String> = emptyList(),
    val states: List<String> = emptyList(),
)
