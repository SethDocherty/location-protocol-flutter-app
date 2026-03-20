/// Configuration for the Privy Auth Modal component.
///
/// Pass this to [PrivyAuthProvider] to configure which login methods
/// are available and how the modal appears.
library;

import 'package:flutter/material.dart';

/// Available login methods for the Privy auth modal.
enum LoginMethod {
  sms(label: 'Continue with SMS', icon: Icons.sms_outlined),
  email(label: 'Continue with Email', icon: Icons.email_outlined),
  google(label: 'Google', icon: Icons.g_mobiledata),
  twitter(label: 'Twitter', icon: Icons.close),
  discord(label: 'Discord', icon: Icons.discord),
  siwe(label: 'Connect Wallet', icon: Icons.account_balance_wallet_outlined);

  const LoginMethod({required this.label, required this.icon});

  /// Default display label shown on the button.
  final String label;

  /// Default icon shown on the button.
  final IconData icon;
}

/// Appearance configuration for the login modal.
class PrivyAuthAppearance {
  /// Title text shown at the top of the modal.
  final String title;

  /// Optional logo widget displayed above the title.
  final Widget? logo;

  /// Background color of the modal. Defaults to surface color from theme.
  final Color? backgroundColor;

  /// Border radius of the modal bottom sheet.
  final double borderRadius;

  /// Footer text displayed at the bottom (e.g., "Protected by Privy").
  final String? footerText;

  const PrivyAuthAppearance({
    this.title = 'Log in or sign up',
    this.logo,
    this.backgroundColor,
    this.borderRadius = 24.0,
    this.footerText = 'Protected by Privy',
  });
}

/// Immutable configuration object for the Privy auth modal.
///
/// Example:
/// ```dart
/// PrivyAuthConfig(
///   appId: 'your-app-id',
///   clientId: 'your-client-id',
///   loginMethods: [LoginMethod.sms, LoginMethod.email, LoginMethod.google],
/// )
/// ```
class PrivyAuthConfig {
  /// Your Privy application ID from the Privy Dashboard.
  final String appId;

  /// Your app client ID from the Privy Dashboard.
  /// Required for mobile/non-web platforms.
  final String clientId;

  /// Which login methods to display in the modal, in order.
  final List<LoginMethod> loginMethods;

  /// Modal appearance configuration.
  final PrivyAuthAppearance appearance;

  /// URL scheme used by OAuth providers to redirect back to the app.
  ///
  /// Required when using OAuth login methods.
  final String? oauthAppUrlScheme;

  /// Whether to auto-create an embedded Ethereum wallet on first login.
  final bool autoCreateWallet;

  /// The domain used when generating a SIWE message (e.g. "myapp.com").
  ///
  /// Required when [LoginMethod.siwe] is enabled. Defaults to "localhost".
  final String siweAppDomain;

  /// The URI used when generating a SIWE message (e.g. "https://myapp.com").
  ///
  /// Required when [LoginMethod.siwe] is enabled. Defaults to "https://localhost".
  final String siweAppUri;

  /// Callback fired when authentication succeeds.
  /// Receives the authenticated user's wallet address (if available).
  final void Function(String? walletAddress)? onAuthenticated;

  /// Callback fired when authentication fails or the user cancels.
  final void Function(String error)? onError;

  const PrivyAuthConfig({
    required this.appId,
    required this.clientId,
    this.loginMethods = const [
      LoginMethod.sms,
      LoginMethod.email,
      LoginMethod.google,
      LoginMethod.twitter,
      LoginMethod.discord,
      LoginMethod.siwe,
    ],
    this.appearance = const PrivyAuthAppearance(),
    this.oauthAppUrlScheme,
    this.autoCreateWallet = true,
    this.siweAppDomain = 'localhost',
    this.siweAppUri = 'https://localhost',
    this.onAuthenticated,
    this.onError,
  });
}
