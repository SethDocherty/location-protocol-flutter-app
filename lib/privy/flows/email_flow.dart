/// Email authentication flow for the Privy auth modal.
///
/// Uses [OtpInputView] to collect an email address, send an OTP via
/// `privy.email.sendCode()`, then verify via `privy.email.loginWithCode()`.
library;

import 'package:flutter/material.dart';

import '../privy_manager.dart';
import '../widgets/otp_input_view.dart';

/// Email login flow: email → OTP → authenticated.
class EmailFlow extends StatelessWidget {
  /// Called with null on success, or a String error.
  final void Function(String? error) onComplete;

  /// Called when the user taps back to return to method selector.
  final VoidCallback onBack;

  const EmailFlow({
    super.key,
    required this.onComplete,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final privy = PrivyManager().privy;

    return OtpInputView(
      identifierLabel: 'Email address',
      identifierHint: 'you@example.com',
      identifierKeyboardType: TextInputType.emailAddress,
      onBack: onBack,
      onSendCode: (email) async {
        final result = await privy.email.sendCode(email);
        bool success = false;
        result.fold(
          onSuccess: (_) => success = true,
          onFailure: (error) {
            debugPrint('Email sendCode error: ${error.message}');
          },
        );
        return success;
      },
      onVerifyCode: (code, email) async {
        final result = await privy.email.loginWithCode(
          code: code,
          email: email,
        );
        bool success = false;
        result.fold(
          onSuccess: (_) {
            success = true;
            onComplete(null);
          },
          onFailure: (error) {
            onComplete(error.message);
          },
        );
        return success;
      },
    );
  }
}
