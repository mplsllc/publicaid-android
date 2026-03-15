package org.publicaid.app.data.repository

import kotlinx.coroutines.flow.Flow
import org.publicaid.app.data.api.UserApi
import org.publicaid.app.data.db.BookmarkDao
import org.publicaid.app.data.db.EntityDao
import org.publicaid.app.data.model.AuthState
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
    private val authRepository: AuthRepository,
    private val userApi: dagger.Lazy<UserApi>,
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

        // If logged in, also sync to server
        if (authRepository.authState.value is AuthState.LoggedIn) {
            try {
                userApi.get().toggleBookmark(entity.id)
            } catch (_: Exception) {
                // Offline — local change persists, will sync later
            }
        }
    }

    suspend fun getBookmarkedEntities(): List<Entity> {
        val ids = bookmarkDao.getAllEntityIds()
        if (ids.isEmpty()) return emptyList()
        val cached = entityDao.getByIds(ids)
        return cached.mapNotNull { entityAdapter.fromJson(it.jsonSnapshot) }
    }

    suspend fun getBookmarkedEntityIds(): List<String> = bookmarkDao.getAllEntityIds()

    /**
     * Merge strategy on login:
     * 1. Push local-only bookmarks to server
     * 2. Pull full server list
     * 3. Replace local Room bookmarks with server list
     */
    suspend fun syncOnLogin() {
        try {
            val localIds = bookmarkDao.getAllEntityIds().toSet()

            // Pull server bookmarks
            val response = userApi.get().listBookmarks()
            val serverBookmarks = response.body()?.data ?: return
            val serverIds = serverBookmarks.map { it.entityId }.toSet()

            // Push local-only items to server
            val localOnly = localIds - serverIds
            localOnly.forEach { entityId ->
                try {
                    userApi.get().toggleBookmark(entityId)
                } catch (_: Exception) { /* skip failed pushes */ }
            }

            // Now pull again to get the full merged list
            val mergedResponse = userApi.get().listBookmarks()
            val mergedBookmarks = mergedResponse.body()?.data ?: return

            // Replace local bookmarks with merged server list
            val currentIds = bookmarkDao.getAllEntityIds()
            currentIds.forEach { bookmarkDao.deleteByEntityId(it) }

            mergedBookmarks.forEach { item ->
                bookmarkDao.insert(Bookmark(entityId = item.entityId))
            }
        } catch (_: Exception) {
            // Network error — keep local bookmarks as-is
        }
    }
}
