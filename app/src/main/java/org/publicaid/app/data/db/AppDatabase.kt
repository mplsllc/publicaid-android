package org.publicaid.app.data.db

import androidx.room.Database
import androidx.room.RoomDatabase
import org.publicaid.app.data.model.Bookmark

@Database(
    entities = [
        CachedEntity::class,
        Bookmark::class,
        SearchCacheEntry::class,
    ],
    version = 1,
    exportSchema = false,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun entityDao(): EntityDao
    abstract fun bookmarkDao(): BookmarkDao
    abstract fun searchCacheDao(): SearchCacheDao
}
