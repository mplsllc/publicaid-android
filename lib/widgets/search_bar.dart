import 'package:flutter/material.dart';
import '../theme.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;
  final bool showFilter;
  final bool autofocus;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search services...',
    this.onSubmitted,
    this.onFilterTap,
    this.showFilter = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: AppColors.mediumGray, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                filled: false,
                hintStyle: const TextStyle(
                  fontFamily: 'DMSans',
                  color: AppColors.mediumGray,
                  fontSize: 15,
                ),
              ),
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 15,
                color: AppColors.navyBlue,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
            ),
          ),
          if (showFilter && onFilterTap != null) ...[
            Container(
              width: 1,
              height: 24,
              color: AppColors.inputBorder,
            ),
            IconButton(
              onPressed: onFilterTap,
              icon: const Icon(Icons.tune, color: AppColors.brightBlue, size: 22),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              constraints: const BoxConstraints(),
            ),
          ] else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}
