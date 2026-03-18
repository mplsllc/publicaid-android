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
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorderOf(context)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, color: AppColors.muted(context), size: 22),
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
                hintStyle: TextStyle(
                  fontFamily: 'DMSans',
                  color: AppColors.muted(context),
                  fontSize: 15,
                ),
              ),
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 15,
                color: AppColors.text(context),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
            ),
          ),
          if (showFilter && onFilterTap != null) ...[
            Container(
              width: 1,
              height: 24,
              color: AppColors.inputBorderOf(context),
            ),
            IconButton(
              onPressed: onFilterTap,
              icon: Icon(Icons.tune, color: AppColors.accent(context), size: 22),
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
