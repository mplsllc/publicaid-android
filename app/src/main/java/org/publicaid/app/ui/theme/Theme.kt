package org.publicaid.app.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

// --- Core palette (matches mobile web) ---
val NavyBlue = Color(0xFF0D3B6E)
val NavyLight = Color(0xFF1A4A7A)
val NavyDark = Color(0xFF051D38)
val BrightBlue = Color(0xFF1565C0)
val FocusBlue = Color(0xFF4A90D9)
val GreenAccent = Color(0xFF2E7D32)
val LightBg = Color(0xFFF4F7FB)
val HeroBg = Color(0xFFE8F0FA)
val CardBorder = Color(0xFFDCE8F5)
val InputBorder = Color(0xFFD0DEF0)
val GrayText = Color(0xFF5A7A9E)
val MediumGray = Color(0xFF8BA8C8)
val GreenBg = Color(0xFFE8F5E9)
val TagBg = Color(0xFFE8EEF6)
val LightTint = Color(0xFFEEF3FB)
val NavBorder = Color(0xFFE2ECF7)

private val PublicaidColors = lightColorScheme(
    primary = NavyBlue,
    onPrimary = Color.White,
    primaryContainer = NavyLight,
    onPrimaryContainer = Color.White,
    secondary = BrightBlue,
    onSecondary = Color.White,
    tertiary = GreenAccent,
    onTertiary = Color.White,
    surface = Color.White,
    onSurface = Color(0xFF1E293B),
    surfaceVariant = HeroBg,
    onSurfaceVariant = GrayText,
    background = LightBg,
    onBackground = Color(0xFF1E293B),
    error = Color(0xFFDC2626),
    onError = Color.White,
    outline = CardBorder,
    outlineVariant = InputBorder,
)

@Immutable
data class PublicaidExtendedColors(
    val focusBlue: Color = FocusBlue,
    val heroBg: Color = HeroBg,
    val cardBorder: Color = CardBorder,
    val inputBorder: Color = InputBorder,
    val grayText: Color = GrayText,
    val mediumGray: Color = MediumGray,
    val greenBg: Color = GreenBg,
    val greenAccent: Color = GreenAccent,
    val tagBg: Color = TagBg,
    val lightTint: Color = LightTint,
    val navBorder: Color = NavBorder,
    val brightBlue: Color = BrightBlue,
    val navyBlue: Color = NavyBlue,
)

val LocalExtendedColors = staticCompositionLocalOf { PublicaidExtendedColors() }

private val PublicaidShapes = Shapes(
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(12.dp),
    large = RoundedCornerShape(16.dp),
)

@Composable
fun PublicaidTheme(content: @Composable () -> Unit) {
    CompositionLocalProvider(
        LocalExtendedColors provides PublicaidExtendedColors(),
    ) {
        MaterialTheme(
            colorScheme = PublicaidColors,
            typography = PublicaidTypography,
            shapes = PublicaidShapes,
            content = content,
        )
    }
}
