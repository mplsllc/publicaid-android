package org.publicaid.app.data.db

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query

@Entity(tableName = "search_cache")
data class SearchCacheEntry(
    @PrimaryKey
    val queryHash: String,
    val responseJson: String,
    val cachedAt: Long = System.currentTimeMillis(),
)

@Dao
interface SearchCacheDao {

    @Query("SELECT * FROM search_cache WHERE queryHash = :hash AND cachedAt > :minAge")
    suspend fun get(hash: String, minAge: Long): SearchCacheEntry?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun put(entry: SearchCacheEntry)

    @Query("DELETE FROM search_cache WHERE cachedAt < :before")
    suspend fun evict(before: Long)

    @Query("SELECT COUNT(*) FROM search_cache")
    suspend fun count(): Int

    @Query("DELETE FROM search_cache WHERE queryHash NOT IN (SELECT queryHash FROM search_cache ORDER BY cachedAt DESC LIMIT 3)")
    suspend fun keepRecent()
}
