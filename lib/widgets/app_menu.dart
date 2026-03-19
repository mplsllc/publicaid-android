import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// User icon button for AppBar — navigates to Account/My Page screen.
class AppMenuButton extends StatelessWidget {
  final void Function(String)? onNavigate;
  final AuthService? authService;

  const AppMenuButton({super.key, this.onNavigate, this.authService});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.person_outline),
      tooltip: 'My Page',
      onPressed: () => onNavigate?.call('account'),
    );
  }
}
