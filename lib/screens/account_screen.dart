import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../services/api_service.dart';

class AccountScreen extends StatelessWidget {
  final AuthService authService;
  final ApiService apiService;

  const AccountScreen({
    super.key,
    required this.authService,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        automaticallyImplyLeading: false,
      ),
      body: ListenableBuilder(
        listenable: authService,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (authService.isLoggedIn)
                  _buildLoggedInCard(context)
                else
                  _buildSignInPrompt(context),
                const SizedBox(height: 24),
                _buildLinks(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoggedInCard(BuildContext context) {
    final user = authService.user;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.heroBg,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.person,
                  size: 32, color: AppColors.brightBlue),
            ),
            const SizedBox(height: 12),
            if (user?.name != null && user!.name!.isNotEmpty)
              Text(
                user.name!,
                style: const TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyBlue,
                ),
              ),
            Text(
              user?.email ?? '',
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: AppColors.grayText,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await authService.logout();
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.heroBg,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.person_outline,
                  size: 28, color: AppColors.brightBlue),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign in to sync your bookmarks',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navyBlue,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create an account to save services across devices',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: AppColors.grayText,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(
                        authService: authService,
                        apiService: apiService,
                      ),
                    ),
                  );
                },
                child: const Text('Sign In'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegisterScreen(
                        authService: authService,
                        apiService: apiService,
                      ),
                    ),
                  );
                },
                child: const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinks(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _linkTile(
            Icons.info_outline,
            'About Publicaid',
            () => _openUrl('https://publicaid.org/about'),
          ),
          const Divider(height: 1),
          _linkTile(
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            () => _openUrl('https://publicaid.org/privacy'),
          ),
          const Divider(height: 1),
          _linkTile(
            Icons.description_outlined,
            'Terms of Service',
            () => _openUrl('https://publicaid.org/terms'),
          ),
        ],
      ),
    );
  }

  Widget _linkTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.brightBlue, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 15,
          color: AppColors.navyBlue,
        ),
      ),
      trailing:
          const Icon(Icons.open_in_new, size: 18, color: AppColors.mediumGray),
    );
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
