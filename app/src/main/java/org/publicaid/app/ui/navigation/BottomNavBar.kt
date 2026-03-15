package org.publicaid.app.ui.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.publicaid.app.ui.theme.LocalExtendedColors

sealed class BottomNavItem(
    val route: String,
    val label: String,
    val icon: ImageVector,
    val selectedIcon: ImageVector,
) {
    data object Home : BottomNavItem(Routes.HOME, "Home", Icons.Outlined.Home, Icons.Filled.Home)
    data object Search : BottomNavItem(Routes.SEARCH_TAB, "Search", Icons.Outlined.Search, Icons.Filled.Search)
    data object Saved : BottomNavItem(Routes.BOOKMARKS, "Saved", Icons.Outlined.BookmarkBorder, Icons.Filled.Bookmark)
    data object Categories : BottomNavItem(Routes.CATEGORIES, "Categories", Icons.Outlined.Category, Icons.Filled.Category)
    data object Account : BottomNavItem(Routes.ACCOUNT, "Account", Icons.Outlined.Person, Icons.Filled.Person)

    companion object {
        val items = listOf(Home, Search, Saved, Categories, Account)
        val routes = items.map { it.route }.toSet()
    }
}

@Composable
fun PublicaidBottomBar(
    currentRoute: String?,
    onNavigate: (BottomNavItem) -> Unit,
) {
    val colors = LocalExtendedColors.current

    Surface(
        color = MaterialTheme.colorScheme.surface,
        shadowElevation = 0.dp,
    ) {
        Column {
            HorizontalDivider(
                thickness = 1.dp,
                color = colors.navBorder,
            )
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface,
                tonalElevation = 0.dp,
            ) {
                BottomNavItem.items.forEach { item ->
                    val selected = currentRoute == item.route
                    NavigationBarItem(
                        selected = selected,
                        onClick = { onNavigate(item) },
                        icon = {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(
                                    imageVector = if (selected) item.selectedIcon else item.icon,
                                    contentDescription = item.label,
                                )
                                if (selected) {
                                    Spacer(Modifier.height(2.dp))
                                    Box(
                                        modifier = Modifier
                                            .size(4.dp)
                                            .clip(CircleShape)
                                            .background(colors.brightBlue),
                                    )
                                }
                            }
                        },
                        label = {
                            Text(
                                text = item.label,
                                fontSize = 10.sp,
                            )
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = colors.brightBlue,
                            selectedTextColor = colors.brightBlue,
                            unselectedIconColor = colors.mediumGray,
                            unselectedTextColor = colors.mediumGray,
                            indicatorColor = MaterialTheme.colorScheme.surface,
                        ),
                    )
                }
            }
        }
    }
}
