package org.publicaid.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Navy = Color(0xFF0A2F57)
private val NavyLight = Color(0xFF1A4A7A)
private val NavyDark = Color(0xFF051D38)
private val Blue = Color(0xFF2563EB)
private val Green = Color(0xFF16A34A)
private val Surface = Color(0xFFF8FAFC)
private val OnSurface = Color(0xFF1E293B)
private val SurfaceVariant = Color(0xFFE2E8F0)

private val PublicaidColors = lightColorScheme(
    primary = Navy,
    onPrimary = Color.White,
    primaryContainer = NavyLight,
    onPrimaryContainer = Color.White,
    secondary = Blue,
    onSecondary = Color.White,
    tertiary = Green,
    onTertiary = Color.White,
    surface = Surface,
    onSurface = OnSurface,
    surfaceVariant = SurfaceVariant,
    onSurfaceVariant = Color(0xFF475569),
    background = Color.White,
    onBackground = OnSurface,
    error = Color(0xFFDC2626),
    onError = Color.White,
    outline = Color(0xFFCBD5E1),
    outlineVariant = Color(0xFFE2E8F0),
)

@Composable
fun PublicaidTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = PublicaidColors,
        typography = PublicaidTypography,
        content = content,
    )
}
