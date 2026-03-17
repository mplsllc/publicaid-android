import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/auth.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/plan_service.dart';
import '../services/vault_service.dart';
import '../theme.dart';
import 'plan_screen.dart';
import 'vault_pin_screen.dart';
import '../widgets/app_menu.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AccountScreen extends StatefulWidget {
  final AuthService authService;
  final ApiService apiService;
  final PlanService? planService;
  final VaultService? vaultService;
  final void Function(String)? onNavigate;

  const AccountScreen({
    super.key,
    required this.authService,
    required this.apiService,
    this.planService,
    this.vaultService,
    this.onNavigate,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  List<BookmarkItem> _saved = [];
  List<BookmarkItem> _supported = [];
  bool _loadingLists = false;

  @override
  void initState() {
    super.initState();
    widget.authService.addListener(_onAuthChanged);
    if (widget.authService.isLoggedIn) _loadLists();
  }

  @override
  void dispose() {
    widget.authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {});
      if (widget.authService.isLoggedIn) _loadLists();
    }
  }

  Future<void> _loadLists() async {
    setState(() => _loadingLists = true);
    try {
      final saved = await widget.apiService.getBookmarks();
      final supported = await widget.apiService.getSupported();
      if (mounted) {
        setState(() {
          _saved = saved;
          _supported = supported;
          _loadingLists = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLists = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          AppMenuButton(
              onNavigate: widget.onNavigate,
              authService: widget.authService),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.authService.isLoggedIn)
              _buildLoggedInCard(context)
            else
              _buildSignInPrompt(context),
            if (widget.authService.isLoggedIn) ...[
              const SizedBox(height: 20),
              _buildSavedSection(),
              const SizedBox(height: 16),
              _buildSupportedSection(),
            ],
            const SizedBox(height: 24),
            _buildLinks(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInCard(BuildContext context) {
    final user = widget.authService.user;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.heroBgOf(context),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(Icons.person,
                  size: 32, color: AppColors.accent(context)),
            ),
            const SizedBox(height: 12),
            if (user?.name != null && user!.name!.isNotEmpty)
              Text(
                user.name!,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              ),
            Text(
              user?.email ?? '',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: AppColors.muted(context),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await widget.authService.logout();
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

  Widget _buildSavedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: AppColors.muted(context),
                  ),
                ),
                Text(
                  '${_saved.length}',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 12,
                    color: AppColors.muted(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingLists)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ))
            else if (_saved.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No saved services yet. Tap the Save button on any listing.',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    color: AppColors.muted(context),
                  ),
                ),
              )
            else
              ...(_saved.map((item) => _buildListItem(
                    icon: Icons.bookmark,
                    iconColor: AppColors.accent(context),
                    item: item,
                  ))),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Supporting',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: AppColors.muted(context),
                  ),
                ),
                Text(
                  '${_supported.length}',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 12,
                    color: AppColors.muted(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingLists)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ))
            else if (_supported.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No supported organizations yet. Tap "I Support" on any listing.',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    color: AppColors.muted(context),
                  ),
                ),
              )
            else
              ...(_supported.map((item) => _buildListItem(
                    icon: Icons.favorite,
                    iconColor: Colors.red,
                    item: item,
                  ))),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(
      {required IconData icon,
      required Color iconColor,
      required BookmarkItem item}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.city != null || item.state != null)
                  Text(
                    [item.city, item.state].where((s) => s != null).join(', '),
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12,
                      color: AppColors.muted(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
                color: AppColors.heroBgOf(context),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.person_outline,
                  size: 28, color: AppColors.accent(context)),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to sync your bookmarks',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create an account to save services across devices',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                color: AppColors.muted(context),
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
                        authService: widget.authService,
                        apiService: widget.apiService,
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
                        authService: widget.authService,
                        apiService: widget.apiService,
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
          if (widget.planService != null)
            ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlanScreen(
                      planService: widget.planService!,
                      apiService: widget.apiService,
                    ),
                  ),
                );
              },
              leading: Icon(Icons.checklist, color: AppColors.accent(context), size: 22),
              title: Text(
                'My Plan',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 15,
                  color: AppColors.text(context),
                ),
              ),
              trailing: Icon(Icons.chevron_right, size: 18, color: AppColors.muted(context)),
            ),
          if (widget.planService != null)
            const Divider(height: 1),
          _linkTile(
            Icons.folder_outlined,
            'Documents',
            () {
              if (widget.vaultService != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VaultPinScreen(
                      vaultService: widget.vaultService!,
                    ),
                  ),
                );
              }
            },
          ),
          const Divider(height: 1),
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
      leading: Icon(icon, color: AppColors.accent(context), size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 15,
          color: AppColors.text(context),
        ),
      ),
      trailing:
          Icon(Icons.open_in_new, size: 18, color: AppColors.muted(context)),
    );
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
