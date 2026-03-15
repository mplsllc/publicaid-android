package org.publicaid.app.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.publicaid.app.data.model.Entity
import org.publicaid.app.ui.theme.LocalExtendedColors
import org.publicaid.app.util.IntentHelper

@Composable
fun EntityCard(
    entity: Entity,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = LocalExtendedColors.current
    val context = LocalContext.current

    val description = buildString {
        append(entity.name)
        entity.distanceMiles?.let { append(", %.1f miles away".format(it)) }
        entity.phone?.let { append(", call $it") }
    }

    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .clearAndSetSemantics { contentDescription = description },
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        border = BorderStroke(1.dp, colors.cardBorder),
        shape = RoundedCornerShape(12.dp),
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // Name + verified badge
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = entity.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = colors.brightBlue,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                if (entity.dataQuality?.isVerified == true) {
                    Icon(
                        imageVector = Icons.Default.Verified,
                        contentDescription = "Verified",
                        tint = colors.greenAccent,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }

            // Category tags + distance badge
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                entity.categories.take(2).forEach { cat ->
                    Surface(
                        color = colors.tagBg,
                        shape = RoundedCornerShape(50),
                    ) {
                        Text(
                            text = cat.name,
                            style = MaterialTheme.typography.labelSmall,
                            color = colors.brightBlue,
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 3.dp),
                        )
                    }
                }
                Spacer(Modifier.weight(1f))
                entity.distanceMiles?.let { miles ->
                    Surface(
                        color = colors.greenBg,
                        shape = RoundedCornerShape(50),
                    ) {
                        Text(
                            text = "%.1f mi".format(miles),
                            style = MaterialTheme.typography.labelSmall,
                            color = colors.greenAccent,
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 3.dp),
                        )
                    }
                }
            }

            // Address
            val address = entity.addressLine
            if (address.isNotBlank()) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        tint = colors.grayText,
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        text = address,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.grayText,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }

            // Phone
            entity.phone?.let { phone ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.Phone,
                        contentDescription = null,
                        tint = colors.grayText,
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        text = phone,
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.grayText,
                    )
                }
            }

            // Action buttons
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(top = 4.dp),
            ) {
                // View Details
                Button(
                    onClick = onClick,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = colors.brightBlue,
                    ),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp),
                    modifier = Modifier.height(34.dp),
                ) {
                    Text("View Details", fontSize = 12.sp)
                }

                // Call
                entity.phone?.let { phone ->
                    OutlinedButton(
                        onClick = { IntentHelper.dial(context, phone) },
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = colors.greenAccent,
                        ),
                        border = BorderStroke(1.dp, colors.greenAccent),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                        modifier = Modifier.height(34.dp),
                    ) {
                        Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Call", fontSize = 12.sp)
                    }
                }

                // Directions
                if (entity.lat != null && entity.lng != null) {
                    OutlinedButton(
                        onClick = { IntentHelper.navigate(context, entity.lat, entity.lng, entity.name) },
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                        modifier = Modifier.height(34.dp),
                    ) {
                        Icon(Icons.Default.Directions, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Directions", fontSize = 12.sp)
                    }
                }
            }
        }
    }
}
