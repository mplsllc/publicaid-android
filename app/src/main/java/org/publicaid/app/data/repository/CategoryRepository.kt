package org.publicaid.app.data.repository

import org.publicaid.app.data.api.PublicaidApi
import org.publicaid.app.data.model.Category
import org.publicaid.app.data.model.FilterValues
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CategoryRepository @Inject constructor(
    private val api: PublicaidApi,
) {
    private var cachedCategories: List<Category>? = null
    private var cachedFilters: FilterValues? = null
    private var lastFetchedAt: Long = 0

    suspend fun getCategories(forceRefresh: Boolean = false): Result<List<Category>> {
        val cached = cachedCategories
        val fresh = System.currentTimeMillis() - lastFetchedAt < CACHE_TTL_MS
        if (!forceRefresh && cached != null && fresh) {
            return Result.success(cached)
        }
        return try {
            val response = api.getCategories()
            cachedCategories = response.data
            lastFetchedAt = System.currentTimeMillis()
            Result.success(response.data)
        } catch (e: Exception) {
            if (cached != null) Result.success(cached) else Result.failure(e)
        }
    }

    suspend fun getFilters(): Result<FilterValues> {
        val cached = cachedFilters
        if (cached != null) return Result.success(cached)
        return try {
            val response = api.getFilters()
            cachedFilters = response.data
            Result.success(response.data)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    companion object {
        private const val CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000L // 1 week
    }
}
