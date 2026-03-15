package org.publicaid.app.ui.screens.account

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Login
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import org.publicaid.app.data.model.AuthState
import org.publicaid.app.ui.theme.LocalExtendedColors
import org.publicaid.app.util.IntentHelper

@Composable
fun AccountScreen(
    onNavigateToLogin: () -> Unit = {},
    onNavigateToRegister: () -> Unit = {},
    viewModel: AccountViewModel = hiltViewModel(),
) {
    val authState by viewModel.authState.collectAsState()
    val colors = LocalExtendedColors.current
    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
    ) {
        Text(
            text = "Account",
            style = MaterialTheme.typography.headlineLarge,
            modifier = Modifier.padding(bottom = 24.dp),
        )

        when (val state = authState) {
            is AuthState.LoggedOut -> {
                // Sign-in prompt card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                    ),
                ) {
                    Column(
                        modifier = Modifier.padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.Login,
                            contentDescription = null,
                            modifier = Modifier.size(48.dp),
                            tint = colors.brightBlue,
                        )
                        Spacer(Modifier.height(12.dp))
                        Text(
                            text = "Sign in to sync your saved services across devices",
                            style = MaterialTheme.typography.bodyLarge,
                            color = colors.grayText,
                        )
                        Spacer(Modifier.height(16.dp))
                        Button(
                            onClick = onNavigateToLogin,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = colors.brightBlue,
                            ),
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("Sign In")
                        }
                        Spacer(Modifier.height(8.dp))
                        OutlinedButton(
                            onClick = onNavigateToRegister,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("Create Account")
                        }
                    }
                }
            }

            is AuthState.LoggedIn -> {
                // Profile card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                    ),
                ) {
                    Column(
                        modifier = Modifier.padding(24.dp),
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(16.dp),
                        ) {
                            Icon(
                                Icons.Default.Person,
                                contentDescription = null,
                                modifier = Modifier.size(48.dp),
                                tint = colors.brightBlue,
                            )
                            Column {
                                Text(
                                    text = state.user.displayName ?: state.user.email,
                                    style = MaterialTheme.typography.titleMedium,
                                )
                                Text(
                                    text = state.user.email,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = colors.grayText,
                                )
                            }
                        }
                        Spacer(Modifier.height(16.dp))
                        OutlinedButton(
                            onClick = { viewModel.logout() },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Icon(
                                Icons.AutoMirrored.Filled.Logout,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(Modifier.width(8.dp))
                            Text("Log Out")
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(32.dp))
        HorizontalDivider(color = colors.navBorder)
        Spacer(Modifier.height(16.dp))

        // Links
        TextButton(onClick = { IntentHelper.openUrl(context, "https://publicaid.org/about") }) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("About Publicaid")
                Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null, modifier = Modifier.size(16.dp))
            }
        }
        TextButton(onClick = { IntentHelper.openUrl(context, "https://publicaid.org/privacy") }) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Privacy Policy")
                Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null, modifier = Modifier.size(16.dp))
            }
        }
        TextButton(onClick = { IntentHelper.openUrl(context, "https://publicaid.org/terms") }) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Terms of Service")
                Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null, modifier = Modifier.size(16.dp))
            }
        }

        Spacer(Modifier.weight(1f))

        // Version
        Text(
            text = "Publicaid v1.0.0",
            style = MaterialTheme.typography.labelSmall,
            color = colors.mediumGray,
            modifier = Modifier.align(Alignment.CenterHorizontally),
        )
    }
}
