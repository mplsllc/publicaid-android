package org.publicaid.app.data.db

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/** Cached entity snapshot for offline bookmarks. Stores the full API JSON. */
@Entity(tableName = "cached_entities")
data class CachedEntity(
    @PrimaryKey
    val id: String,

    val name: String,
    val slug: String,
    val phone: String? = null,
    val website: String? = null,

    @ColumnInfo(name = "address_line1")
    val addressLine1: String? = null,
    val city: String? = null,
    val state: String? = null,
    val zip: String? = null,
    val lat: Double? = null,
    val lng: Double? = null,
    val description: String? = null,

    /** Full API JSON for hydrating the complete Entity model offline. */
    @ColumnInfo(name = "json_snapshot")
    val jsonSnapshot: String,

    @ColumnInfo(name = "cached_at")
    val cachedAt: Long = System.currentTimeMillis(),
)
