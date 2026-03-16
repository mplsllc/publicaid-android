import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _activeColor = Color(0xFF1565C0);
  static const _inactiveColor = Color(0xFF8BA8C8);

  void _handleTap(int index) {
    if (index == 3) {
      // Blog — same tab on web, in-app browser on mobile
      launchUrl(
        Uri.parse('https://publicaid.org/blog'),
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
        webOnlyWindowName: kIsWeb ? '_self' : null,
      );
      return;
    }
    if (index == 4) {
      // Crisis — dial 988
      launchUrl(Uri.parse('tel:988'));
      return;
    }
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2ECF7), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D3B6E).withAlpha(18),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTab(0, Icons.home_outlined, Icons.home, 'Home'),
              _buildTab(1, Icons.search, Icons.search, 'Search'),
              _buildTab(
                  2, Icons.help_outline, Icons.help, 'Get Help'),
              _buildTab(
                  3, Icons.menu_book_outlined, Icons.menu_book, 'Blog'),
              _buildTab(4, Icons.phone_outlined, Icons.phone, 'Crisis'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(
      int index, IconData icon, IconData activeIcon, String label) {
    // Blog (3) and Crisis (4) are never "active" since they're external
    final isActive = index < 3 && currentIndex == index;
    final color = isActive ? _activeColor : _inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? _activeColor : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
