package org.publicaid.app.data.db

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow
import org.publicaid.app.data.model.Bookmark

@Dao
interface BookmarkDao {

    @Query("SELECT * FROM bookmarks ORDER BY created_at DESC")
    fun observeAll(): Flow<List<Bookmark>>

    @Query("SELECT entity_id FROM bookmarks")
    suspend fun getAllEntityIds(): List<String>

    @Query("SELECT EXISTS(SELECT 1 FROM bookmarks WHERE entity_id = :entityId)")
    fun isBookmarked(entityId: String): Flow<Boolean>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(bookmark: Bookmark)

    @Query("DELETE FROM bookmarks WHERE entity_id = :entityId")
    suspend fun deleteByEntityId(entityId: String)

    @Query("SELECT COUNT(*) FROM bookmarks")
    suspend fun count(): Int
}
