package org.publicaid.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import org.publicaid.app.ui.screens.bookmarks.BookmarksScreen
import org.publicaid.app.ui.screens.categories.CategoriesScreen
import org.publicaid.app.ui.screens.detail.DetailScreen
import org.publicaid.app.ui.screens.home.HomeScreen
import org.publicaid.app.ui.screens.search.SearchScreen

object Routes {
    const val HOME = "home"
    const val SEARCH = "search?query={query}&category={category}&lat={lat}&lng={lng}"
    const val DETAIL = "detail/{entityId}"
    const val BOOKMARKS = "bookmarks"
    const val CATEGORIES = "categories"

    fun search(
        query: String = "",
        category: String? = null,
        lat: Double? = null,
        lng: Double? = null,
    ): String {
        val params = mutableListOf<String>()
        if (query.isNotBlank()) params.add("query=$query")
        category?.let { params.add("category=$it") }
        lat?.let { params.add("lat=$it") }
        lng?.let { params.add("lng=$it") }
        return "search?${params.joinToString("&")}"
    }

    fun detail(entityId: String) = "detail/$entityId"
}

@Composable
fun PublicaidNavHost() {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = Routes.HOME,
    ) {
        composable(Routes.HOME) {
            HomeScreen(
                onSearch = { query, lat, lng ->
                    navController.navigate(Routes.search(query, lat = lat, lng = lng))
                },
                onCategoryClick = { slug, lat, lng ->
                    navController.navigate(Routes.search(category = slug, lat = lat, lng = lng))
                },
                onNavigateToBookmarks = {
                    navController.navigate(Routes.BOOKMARKS)
                },
            )
        }

        composable(
            route = Routes.SEARCH,
            arguments = listOf(
                navArgument("query") { type = NavType.StringType; defaultValue = "" },
                navArgument("category") { type = NavType.StringType; defaultValue = "" ; nullable = true },
                navArgument("lat") { type = NavType.StringType; defaultValue = ""; nullable = true },
                navArgument("lng") { type = NavType.StringType; defaultValue = ""; nullable = true },
            ),
        ) {
            SearchScreen(
                onEntityClick = { id ->
                    navController.navigate(Routes.detail(id))
                },
                onBack = { navController.popBackStack() },
            )
        }

        composable(
            route = Routes.DETAIL,
            arguments = listOf(
                navArgument("entityId") { type = NavType.StringType },
            ),
        ) {
            DetailScreen(
                onBack = { navController.popBackStack() },
            )
        }

        composable(Routes.BOOKMARKS) {
            BookmarksScreen(
                onEntityClick = { id ->
                    navController.navigate(Routes.detail(id))
                },
                onBack = { navController.popBackStack() },
            )
        }

        composable(Routes.CATEGORIES) {
            CategoriesScreen(
                onCategoryClick = { slug ->
                    navController.navigate(Routes.search(category = slug))
                },
                onBack = { navController.popBackStack() },
            )
        }
    }
}
