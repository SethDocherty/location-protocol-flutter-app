/// OAuth authentication flow for the Privy auth modal.
///
/// Handles Google, Twitter, Discord, and other OAuth providers
/// via `privy.oAuth.login()`.
library;

import 'package:flutter/material.dart';
import 'package:privy_flutter/privy_flutter.dart';

import '../privy_auth_config.dart';
import '../privy_manager.dart';

/// Maps [LoginMethod] OAuth entries to Privy SDK [OAuthProvider] values.
OAuthProvider _toOAuthProvider(LoginMethod method) {
  return switch (method) {
    LoginMethod.google => OAuthProvider.google,
    LoginMethod.twitter => OAuthProvider.twitter,
    LoginMethod.discord => OAuthProvider.discord,
    _ => throw ArgumentError('$method is not an OAuth login method'),
  };
}

/// OAuth login flow: taps button → opens browser → returns authenticated.
class OAuthFlow extends StatefulWidget {
  /// Which OAuth provider to authenticate with.
  final LoginMethod method;

  /// URL scheme used by OAuth provider redirects.
  final String appUrlScheme;

  /// Called with null on success, or a String error.
  final void Function(String? error) onComplete;

  /// Called when the user taps back to return to method selector.
  final VoidCallback onBack;

  const OAuthFlow({
    super.key,
    required this.method,
    required this.appUrlScheme,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<OAuthFlow> createState() => _OAuthFlowState();
}

class _OAuthFlowState extends State<OAuthFlow> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startOAuth();
  }

  Future<void> _startOAuth() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = _toOAuthProvider(widget.method);
      final result = await PrivyManager().privy.oAuth.login(
        provider: provider,
        appUrlScheme: widget.appUrlScheme,
      );

      if (!mounted) return;

      result.fold(
        onSuccess: (_) {
          widget.onComplete(null);
        },
        onFailure: (error) {
          setState(() {
            _loading = false;
            _error = error.message;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providerName = widget.method.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onBack,
            ),
            Expanded(
              child: Text(
                providerName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (_loading) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text(
            'Connecting to $providerName...',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        if (_error != null) ...[
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _startOAuth,
            child: const Text('Try Again'),
          ),
        ],
      ],
    );
  }
}
