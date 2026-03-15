package org.publicaid.app.data.repository

import com.squareup.moshi.Moshi
import org.publicaid.app.data.api.PublicaidApi
import org.publicaid.app.data.db.CachedEntity
import org.publicaid.app.data.db.EntityDao
import org.publicaid.app.data.model.Entity
import org.publicaid.app.data.model.EntityHours
import org.publicaid.app.data.model.EntityService
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class EntityRepository @Inject constructor(
    private val api: PublicaidApi,
    private val entityDao: EntityDao,
) {
    private val moshi = Moshi.Builder().build()
    private val entityAdapter = moshi.adapter(Entity::class.java)

    suspend fun getEntity(id: String): Result<Entity> {
        return try {
            val response = api.getEntity(id)
            val entity = response.data
            // Cache snapshot
            cacheEntity(entity)
            Result.success(entity)
        } catch (e: Exception) {
            // Fallback to cache
            val cached = entityDao.getById(id)
            if (cached != null) {
                val entity = entityAdapter.fromJson(cached.jsonSnapshot)
                if (entity != null) return Result.success(entity)
            }
            Result.failure(e)
        }
    }

    suspend fun getEntityServices(id: String): Result<List<EntityService>> {
        return try {
            Result.success(api.getEntityServices(id).data)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getEntityHours(id: String): Result<List<EntityHours>> {
        return try {
            Result.success(api.getEntityHours(id).data)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun cacheEntity(entity: Entity) {
        val json = entityAdapter.toJson(entity)
        entityDao.upsert(
            CachedEntity(
                id = entity.id,
                name = entity.name,
                slug = entity.slug,
                phone = entity.phone,
                website = entity.website,
                addressLine1 = entity.addressLine1,
                city = entity.city,
                state = entity.state,
                zip = entity.zip,
                lat = entity.lat,
                lng = entity.lng,
                description = entity.description,
                jsonSnapshot = json,
            )
        )
    }
}
