/// A styled button for a single login method in the auth modal.
///
/// Renders an icon + label in a rounded bordered row, matching
/// the Privy login modal aesthetic.
library;

import 'package:flutter/material.dart';

import '../privy_auth_config.dart';

/// A single login method button displayed in the method selector.
class LoginMethodButton extends StatelessWidget {
  /// The login method this button represents.
  final LoginMethod method;

  /// Called when the user taps this button.
  final VoidCallback onTap;

  /// Optional icon override (defaults to [LoginMethod.icon]).
  final Widget? customIcon;

  /// Optional label override (defaults to [LoginMethod.label]).
  final String? customLabel;

  const LoginMethodButton({
    super.key,
    required this.method,
    required this.onTap,
    this.customIcon,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = customLabel ?? method.label;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          backgroundColor: theme.colorScheme.surface,
        ),
        child: Row(
          children: [
            customIcon ??
                Icon(method.icon, size: 24, color: theme.colorScheme.onSurface),
            const SizedBox(width: 16),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
