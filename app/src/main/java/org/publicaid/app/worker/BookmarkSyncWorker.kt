package org.publicaid.app.worker

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.*
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import org.publicaid.app.data.api.BatchRequest
import org.publicaid.app.data.api.PublicaidApi
import org.publicaid.app.data.db.BookmarkDao
import org.publicaid.app.data.model.AuthState
import org.publicaid.app.data.repository.AuthRepository
import org.publicaid.app.data.repository.BookmarkRepository
import org.publicaid.app.data.repository.EntityRepository
import java.util.concurrent.TimeUnit

/**
 * Refreshes cached entity data for all bookmarked entities.
 * If logged in, also syncs bookmarks with the server.
 * Runs every 24 hours via WorkManager + on app foreground as fallback.
 */
@HiltWorker
class BookmarkSyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val api: PublicaidApi,
    private val bookmarkDao: BookmarkDao,
    private val entityRepository: EntityRepository,
    private val authRepository: AuthRepository,
    private val bookmarkRepository: BookmarkRepository,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        // If logged in, sync bookmarks with server first
        if (authRepository.authState.value is AuthState.LoggedIn) {
            try {
                bookmarkRepository.syncOnLogin()
            } catch (_: Exception) {
                // Continue with local cache refresh even if server sync fails
            }
        }

        val entityIds = bookmarkDao.getAllEntityIds()
        if (entityIds.isEmpty()) return Result.success()

        return try {
            // Batch fetch in chunks of 25 (free tier limit)
            entityIds.chunked(25).forEach { chunk ->
                val response = api.batchEntities(BatchRequest(chunk))
                response.data.forEach { entity ->
                    entityRepository.cacheEntity(entity)
                }
            }
            Result.success()
        } catch (e: Exception) {
            if (runAttemptCount < 3) Result.retry() else Result.failure()
        }
    }

    companion object {
        const val WORK_NAME = "bookmark_sync"

        fun enqueue(workManager: WorkManager) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(false)
                .setRequiresCharging(false)
                .build()

            val request = PeriodicWorkRequestBuilder<BookmarkSyncWorker>(
                24, TimeUnit.HOURS,
                4, TimeUnit.HOURS,
            )
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.MINUTES)
                .build()

            workManager.enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }
    }
}
