import 'package:flutter/material.dart';

/// Shows the hamburger menu as a bottom sheet.
void showAppMenu(BuildContext context, {void Function(String)? onNavigate}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0A2F57),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _menuItem(ctx, Icons.home_outlined, 'Home', () {
              Navigator.pop(ctx);
              onNavigate?.call('home');
            }),
            _menuItem(ctx, Icons.login, 'Sign In', () {
              Navigator.pop(ctx);
              onNavigate?.call('login');
            }),
            _menuItem(ctx, Icons.person_outline, 'My Page', () {
              Navigator.pop(ctx);
              onNavigate?.call('account');
            }),
            _menuItem(ctx, Icons.settings_outlined, 'Settings', () {
              Navigator.pop(ctx);
              onNavigate?.call('account');
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

Widget _menuItem(
    BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withAlpha(179), size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 15,
              color: Colors.white.withAlpha(179),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Hamburger menu icon button for AppBar actions.
/// If [onNavigate] is null, the menu items will be no-ops.
class AppMenuButton extends StatelessWidget {
  final void Function(String)? onNavigate;

  const AppMenuButton({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      onPressed: () => showAppMenu(context, onNavigate: onNavigate),
    );
  }
}
