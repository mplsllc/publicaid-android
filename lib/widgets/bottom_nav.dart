import 'package:flutter/material.dart';
import '../theme.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  void _handleTap(int index) {
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.navBorder;
    final shadowColor = isDark ? Colors.black26 : AppColors.navyBlue.withAlpha(18);
    final activeColor = isDark ? AppColors.lightBlue : AppColors.brightBlue;
    final inactiveColor = isDark ? AppColors.darkGrayText : AppColors.mediumGray;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTab(0, Icons.home_outlined, Icons.home, 'Home', activeColor, inactiveColor),
              _buildTab(1, Icons.search, Icons.search, 'Search', activeColor, inactiveColor),
              _buildTab(2, Icons.help_outline, Icons.help, 'Get Help', activeColor, inactiveColor),
              _buildTab(3, Icons.menu_book_outlined, Icons.menu_book, 'Blog', activeColor, inactiveColor),
              _buildTab(4, Icons.phone_outlined, Icons.phone, 'Crisis', activeColor, inactiveColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(
      int index, IconData icon, IconData activeIcon, String label,
      Color activeColor, Color inactiveColor) {
    final isActive = currentIndex == index;
    final color = isActive ? activeColor : inactiveColor;

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
                color: isActive ? activeColor : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
