/// The main login modal entry point.
///
/// Call [showPrivyLoginModal] to open a bottom sheet with all configured
/// login methods. The modal auto-dismisses on successful authentication.
///
/// ```dart
/// await showPrivyLoginModal(context);
/// ```
library;

import 'package:flutter/material.dart';
import 'package:privy_flutter/privy_flutter.dart';

import 'flows/email_flow.dart';
import 'flows/oauth_flow.dart';
import 'flows/siwe_flow.dart';
import 'flows/sms_flow.dart';
import 'privy_auth_config.dart';
import 'privy_auth_provider.dart';
import 'widgets/login_method_button.dart';

/// Opens the Privy login modal as a bottom sheet.
///
/// Returns the [PrivyUser] on successful authentication, or null
/// if the user dismisses the modal.
///
/// Requires a [PrivyAuthProvider] ancestor in the widget tree.
Future<PrivyUser?> showPrivyLoginModal(BuildContext context) {
  final config = PrivyAuthProvider.configOf(context);

  return showModalBottomSheet<PrivyUser>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(config.appearance.borderRadius),
      ),
    ),
    backgroundColor: config.appearance.backgroundColor ??
        Theme.of(context).colorScheme.surface,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => _LoginModalRoot(
        config: config,
        scrollController: scrollController,
      ),
    ),
  );
}

/// The root widget inside the bottom sheet, managing which "page" is visible.
class _LoginModalRoot extends StatefulWidget {
  final PrivyAuthConfig config;
  final ScrollController scrollController;

  const _LoginModalRoot({
    required this.config,
    required this.scrollController,
  });

  @override
  State<_LoginModalRoot> createState() => _LoginModalRootState();
}

/// Tracks which view is currently displayed in the modal.
enum _ModalPage { selector, sms, email, oauth, siwe }

class _LoginModalRootState extends State<_LoginModalRoot> {
  _ModalPage _page = _ModalPage.selector;
  LoginMethod? _activeOAuthMethod;

  void _goTo(_ModalPage page, {LoginMethod? oauthMethod}) {
    setState(() {
      _page = page;
      _activeOAuthMethod = oauthMethod;
    });
  }

  void _goBack() => _goTo(_ModalPage.selector);

  void _onFlowComplete(String? error) {
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      widget.config.onError?.call(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildCurrentPage(),
      ),
    );
  }

  Widget _buildCurrentPage() {
    return switch (_page) {
      _ModalPage.selector => _buildSelector(),
      _ModalPage.sms => SmsFlow(
          key: const ValueKey('sms'),
          onComplete: _onFlowComplete,
          onBack: _goBack,
        ),
      _ModalPage.email => EmailFlow(
          key: const ValueKey('email'),
          onComplete: _onFlowComplete,
          onBack: _goBack,
        ),
      _ModalPage.oauth => OAuthFlow(
          key: ValueKey('oauth-${_activeOAuthMethod?.name}'),
          method: _activeOAuthMethod!,
          appUrlScheme: widget.config.oauthAppUrlScheme ?? '',
          onComplete: _onFlowComplete,
          onBack: _goBack,
        ),
      _ModalPage.siwe => SiweFlow(
          key: const ValueKey('siwe'),
          config: widget.config,
          onComplete: _onFlowComplete,
          onBack: _goBack,
        ),
    };
  }

  Widget _buildSelector() {
    final theme = Theme.of(context);
    final config = widget.config;
    final appearance = config.appearance;

    return Column(
      key: const ValueKey('selector'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (appearance.logo != null) ...[
          Center(child: appearance.logo!),
          const SizedBox(height: 12),
        ],
        Text(
          appearance.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        for (final method in config.loginMethods)
          LoginMethodButton(
            method: method,
            onTap: () => _onMethodSelected(method),
          ),
        if (appearance.footerText != null) ...[
          const SizedBox(height: 24),
          Text(
            appearance.footerText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  void _onMethodSelected(LoginMethod method) {
    switch (method) {
      case LoginMethod.sms:
        _goTo(_ModalPage.sms);
      case LoginMethod.email:
        _goTo(_ModalPage.email);
      case LoginMethod.google:
      case LoginMethod.twitter:
      case LoginMethod.discord:
        if (widget.config.oauthAppUrlScheme == null ||
            widget.config.oauthAppUrlScheme!.isEmpty) {
          widget.config.onError?.call(
            'OAuth login requires PrivyAuthConfig.oauthAppUrlScheme to be set.',
          );
          return;
        }
        _goTo(_ModalPage.oauth, oauthMethod: method);
      case LoginMethod.siwe:
        _goTo(_ModalPage.siwe);
    }
  }
}
