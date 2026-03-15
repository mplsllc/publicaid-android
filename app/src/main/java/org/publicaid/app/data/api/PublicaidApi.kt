package org.publicaid.app.data.api

import org.publicaid.app.data.model.*
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

interface PublicaidApi {

    // --- Search & Discovery ---

    @GET("search")
    suspend fun search(
        @Query("q") query: String? = null,
        @Query("state") state: String? = null,
        @Query("category") category: String? = null,
        @Query("city") city: String? = null,
        @Query("language") language: String? = null,
        @Query("payment_type") paymentType: String? = null,
        @Query("population") population: String? = null,
        @Query("accessibility") accessibility: String? = null,
        @Query("sort") sort: String? = null,
        @Query("lat") lat: Double? = null,
        @Query("lng") lng: Double? = null,
        @Query("limit") limit: Int? = null,
        @Query("offset") offset: Int? = null,
    ): ApiResponse<List<Entity>>

    @GET("nearby")
    suspend fun nearby(
        @Query("lat") lat: Double,
        @Query("lng") lng: Double,
        @Query("radius") radius: Double? = null,
        @Query("q") query: String? = null,
        @Query("category") category: String? = null,
        @Query("limit") limit: Int? = null,
    ): ApiResponse<List<Entity>>

    // --- Entity Lookups ---

    @GET("entities/{id}")
    suspend fun getEntity(
        @Path("id") id: String,
    ): ApiResponse<Entity>

    @GET("entities/by-slug/{slug}")
    suspend fun getEntityBySlug(
        @Path("slug") slug: String,
    ): ApiResponse<Entity>

    @POST("entities/batch")
    suspend fun batchEntities(
        @Body body: BatchRequest,
    ): ApiResponse<List<Entity>>

    // --- Entity Details ---

    @GET("entities/{id}/services")
    suspend fun getEntityServices(
        @Path("id") id: String,
    ): ApiResponse<List<EntityService>>

    @GET("entities/{id}/hours")
    suspend fun getEntityHours(
        @Path("id") id: String,
    ): ApiResponse<List<EntityHours>>

    // --- Reference Data ---

    @GET("categories")
    suspend fun getCategories(): ApiResponse<List<Category>>

    @GET("categories/{slug}")
    suspend fun getCategory(
        @Path("slug") slug: String,
    ): ApiResponse<Category>

    @GET("filters")
    suspend fun getFilters(): ApiResponse<FilterValues>

    @GET("stats")
    suspend fun getStats(): ApiResponse<StatsResponse>
}

data class BatchRequest(val ids: List<String>)
