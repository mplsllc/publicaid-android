package org.publicaid.app.worker

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.*
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import org.publicaid.app.data.api.BatchRequest
import org.publicaid.app.data.api.PublicaidApi
import org.publicaid.app.data.db.BookmarkDao
import org.publicaid.app.data.repository.EntityRepository
import java.util.concurrent.TimeUnit

/**
 * Refreshes cached entity data for all bookmarked entities.
 * Runs every 24 hours via WorkManager + on app foreground as fallback.
 * Constraints: requires network, does NOT require charging.
 */
@HiltWorker
class BookmarkSyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val api: PublicaidApi,
    private val bookmarkDao: BookmarkDao,
    private val entityRepository: EntityRepository,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
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
                .setRequiresCharging(false) // Users may not charge often
                .build()

            val request = PeriodicWorkRequestBuilder<BookmarkSyncWorker>(
                24, TimeUnit.HOURS,
                4, TimeUnit.HOURS, // flex interval
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
