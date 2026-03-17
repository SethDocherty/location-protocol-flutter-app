/// SMS authentication flow for the Privy auth modal.
///
/// Uses [OtpInputView] to collect a phone number, send an OTP via
/// `privy.sms.sendCode()`, then verify via `privy.sms.loginWithCode()`.
library;

import 'package:flutter/material.dart';

import '../privy_manager.dart';
import '../widgets/otp_input_view.dart';

/// SMS login flow: phone number → OTP → authenticated.
class SmsFlow extends StatelessWidget {
  /// Called with null on success (modal dismisses), or a String error.
  final void Function(String? error) onComplete;

  /// Called when the user taps back to return to method selector.
  final VoidCallback onBack;

  const SmsFlow({
    super.key,
    required this.onComplete,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final privy = PrivyManager().privy;

    return OtpInputView(
      identifierLabel: 'Phone number',
      identifierHint: '+1 234 567 8900',
      identifierKeyboardType: TextInputType.phone,
      onBack: onBack,
      onSendCode: (phone) async {
        final result = await privy.sms.sendCode(phone);
        bool success = false;
        result.fold(
          onSuccess: (_) => success = true,
          onFailure: (error) {
            debugPrint('SMS sendCode error: ${error.message}');
          },
        );
        return success;
      },
      onVerifyCode: (code, phone) async {
        final result = await privy.sms.loginWithCode(
          code: code,
          phoneNumber: phone,
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
