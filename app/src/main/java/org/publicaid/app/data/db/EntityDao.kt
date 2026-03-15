package org.publicaid.app.data.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface EntityDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: CachedEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<CachedEntity>)

    @Query("SELECT * FROM cached_entities WHERE id = :id")
    suspend fun getById(id: String): CachedEntity?

    @Query("SELECT * FROM cached_entities WHERE id IN (:ids)")
    suspend fun getByIds(ids: List<String>): List<CachedEntity>

    @Query("DELETE FROM cached_entities WHERE id NOT IN (SELECT entity_id FROM bookmarks) AND cached_at < :before")
    suspend fun evictStale(before: Long)
}
