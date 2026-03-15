package org.publicaid.app.data.model

import androidx.room.ColumnInfo
import androidx.room.Entity as RoomEntity
import androidx.room.PrimaryKey

/** Local bookmark — references a cached entity snapshot. */
@RoomEntity(tableName = "bookmarks")
data class Bookmark(
    @PrimaryKey
    @ColumnInfo(name = "entity_id")
    val entityId: String,

    val notes: String? = null,

    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
)
