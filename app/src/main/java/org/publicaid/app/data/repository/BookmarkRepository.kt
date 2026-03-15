package org.publicaid.app.data.repository

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.publicaid.app.data.db.BookmarkDao
import org.publicaid.app.data.db.EntityDao
import org.publicaid.app.data.model.Bookmark
import org.publicaid.app.data.model.Entity
import com.squareup.moshi.Moshi
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BookmarkRepository @Inject constructor(
    private val bookmarkDao: BookmarkDao,
    private val entityDao: EntityDao,
    private val entityRepository: EntityRepository,
) {
    private val moshi = Moshi.Builder().build()
    private val entityAdapter = moshi.adapter(Entity::class.java)

    fun isBookmarked(entityId: String): Flow<Boolean> = bookmarkDao.isBookmarked(entityId)

    fun observeBookmarks(): Flow<List<Bookmark>> = bookmarkDao.observeAll()

    suspend fun toggle(entity: Entity) {
        val exists = bookmarkDao.getAllEntityIds().contains(entity.id)
        if (exists) {
            bookmarkDao.deleteByEntityId(entity.id)
        } else {
            entityRepository.cacheEntity(entity)
            bookmarkDao.insert(Bookmark(entityId = entity.id))
        }
    }

    suspend fun getBookmarkedEntities(): List<Entity> {
        val ids = bookmarkDao.getAllEntityIds()
        if (ids.isEmpty()) return emptyList()
        val cached = entityDao.getByIds(ids)
        return cached.mapNotNull { entityAdapter.fromJson(it.jsonSnapshot) }
    }

    suspend fun getBookmarkedEntityIds(): List<String> = bookmarkDao.getAllEntityIds()
}
