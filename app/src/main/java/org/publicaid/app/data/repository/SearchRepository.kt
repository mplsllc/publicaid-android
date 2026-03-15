package org.publicaid.app.data.repository

import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import org.publicaid.app.data.api.PublicaidApi
import org.publicaid.app.data.db.SearchCacheDao
import org.publicaid.app.data.db.SearchCacheEntry
import org.publicaid.app.data.model.ApiResponse
import org.publicaid.app.data.model.Entity
import java.security.MessageDigest
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SearchRepository @Inject constructor(
    private val api: PublicaidApi,
    private val cacheDao: SearchCacheDao,
) {
    private val moshi = Moshi.Builder().build()
    private val listType = Types.newParameterizedType(List::class.java, Entity::class.java)
    private val adapter = moshi.adapter<List<Entity>>(listType)

    suspend fun search(
        query: String? = null,
        state: String? = null,
        category: String? = null,
        city: String? = null,
        language: String? = null,
        paymentType: String? = null,
        population: String? = null,
        accessibility: String? = null,
        sort: String? = null,
        lat: Double? = null,
        lng: Double? = null,
        limit: Int? = null,
        offset: Int? = null,
    ): Result<ApiResponse<List<Entity>>> {
        return try {
            val response = api.search(
                query, state, category, city, language, paymentType,
                population, accessibility, sort, lat, lng, limit, offset
            )
            // Cache if offset=0 (first page only)
            if (offset == null || offset == 0) {
                val hash = hashQuery(query, state, category, city, lat, lng)
                val json = adapter.toJson(response.data)
                cacheDao.put(SearchCacheEntry(hash, json))
                cacheDao.keepRecent()
            }
            Result.success(response)
        } catch (e: Exception) {
            // Try cache fallback
            val hash = hashQuery(query, state, category, city, lat, lng)
            val ttl = System.currentTimeMillis() - CACHE_TTL_MS
            val cached = cacheDao.get(hash, ttl)
            if (cached != null) {
                val entities = adapter.fromJson(cached.responseJson) ?: emptyList()
                Result.success(ApiResponse(entities, null))
            } else {
                Result.failure(e)
            }
        }
    }

    suspend fun nearby(
        lat: Double,
        lng: Double,
        radius: Double? = null,
        query: String? = null,
        category: String? = null,
        limit: Int? = null,
    ): Result<ApiResponse<List<Entity>>> {
        return try {
            Result.success(api.nearby(lat, lng, radius, query, category, limit))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private fun hashQuery(vararg parts: Any?): String {
        val raw = parts.filterNotNull().joinToString("|")
        val bytes = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }.take(16)
    }

    companion object {
        private const val CACHE_TTL_MS = 24 * 60 * 60 * 1000L // 24 hours
    }
}
