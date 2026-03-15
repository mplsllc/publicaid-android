package org.publicaid.app.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.hilt.navigation.compose.hiltViewModel
import org.publicaid.app.ui.screens.account.AccountScreen
import org.publicaid.app.ui.screens.account.AccountViewModel
import org.publicaid.app.ui.screens.account.LoginScreen
import org.publicaid.app.ui.screens.account.RegisterScreen
import org.publicaid.app.ui.screens.bookmarks.BookmarksScreen
import org.publicaid.app.ui.screens.categories.CategoriesScreen
import org.publicaid.app.ui.screens.detail.DetailScreen
import org.publicaid.app.ui.screens.home.HomeScreen
import org.publicaid.app.ui.screens.search.SearchScreen

object Routes {
    const val HOME = "home"
    const val SEARCH = "search?query={query}&category={category}&lat={lat}&lng={lng}"
    const val SEARCH_TAB = "search_tab"
    const val DETAIL = "detail/{entityId}"
    const val BOOKMARKS = "bookmarks"
    const val CATEGORIES = "categories"
    const val ACCOUNT = "account"
    const val LOGIN = "login"
    const val REGISTER = "register"

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
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    val showBottomBar = currentRoute in BottomNavItem.routes

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                PublicaidBottomBar(
                    currentRoute = currentRoute,
                    onNavigate = { item ->
                        navController.navigate(item.route) {
                            popUpTo(Routes.HOME) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                )
            }
        },
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = Routes.HOME,
            modifier = Modifier.padding(padding),
        ) {
            composable(Routes.HOME) {
                HomeScreen(
                    onSearch = { query, lat, lng ->
                        navController.navigate(Routes.search(query, lat = lat, lng = lng))
                    },
                    onCategoryClick = { slug, lat, lng ->
                        navController.navigate(Routes.search(category = slug, lat = lat, lng = lng))
                    },
                )
            }

            composable(Routes.SEARCH_TAB) {
                SearchScreen(
                    onEntityClick = { id ->
                        navController.navigate(Routes.detail(id))
                    },
                    onBack = { navController.popBackStack() },
                )
            }

            composable(
                route = Routes.SEARCH,
                arguments = listOf(
                    navArgument("query") { type = NavType.StringType; defaultValue = "" },
                    navArgument("category") { type = NavType.StringType; defaultValue = ""; nullable = true },
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
                )
            }

            composable(Routes.CATEGORIES) {
                CategoriesScreen(
                    onCategoryClick = { slug ->
                        navController.navigate(Routes.search(category = slug))
                    },
                )
            }

            composable(Routes.ACCOUNT) {
                AccountScreen(
                    onNavigateToLogin = { navController.navigate(Routes.LOGIN) },
                    onNavigateToRegister = { navController.navigate(Routes.REGISTER) },
                )
            }

            composable(Routes.LOGIN) {
                val parentEntry = navController.getBackStackEntry(Routes.ACCOUNT)
                val viewModel: AccountViewModel = hiltViewModel(parentEntry)
                LoginScreen(
                    viewModel = viewModel,
                    onBack = { navController.popBackStack() },
                    onNavigateToRegister = {
                        navController.navigate(Routes.REGISTER) {
                            popUpTo(Routes.ACCOUNT)
                        }
                    },
                    onLoginSuccess = {
                        navController.popBackStack(Routes.ACCOUNT, inclusive = false)
                    },
                )
            }

            composable(Routes.REGISTER) {
                val parentEntry = navController.getBackStackEntry(Routes.ACCOUNT)
                val viewModel: AccountViewModel = hiltViewModel(parentEntry)
                RegisterScreen(
                    viewModel = viewModel,
                    onBack = { navController.popBackStack() },
                    onRegistrationSuccess = {
                        navController.navigate(Routes.LOGIN) {
                            popUpTo(Routes.ACCOUNT)
                        }
                    },
                )
            }
        }
    }
}
