package org.publicaid.app.data.db

import android.content.Context
import androidx.room.Room
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(
            context,
            AppDatabase::class.java,
            "publicaid.db"
        ).build()
    }

    @Provides fun provideEntityDao(db: AppDatabase) = db.entityDao()
    @Provides fun provideBookmarkDao(db: AppDatabase) = db.bookmarkDao()
    @Provides fun provideSearchCacheDao(db: AppDatabase) = db.searchCacheDao()
}
