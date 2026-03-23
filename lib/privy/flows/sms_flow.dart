/// SMS authentication flow for the Privy auth modal.
///
/// Uses [OtpInputView] to collect a phone number, send an OTP via
/// `privy.sms.sendCode()`, then verify via `privy.sms.loginWithCode()`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      initialIdentifier: '+1 ',
      identifierInputFormatters: [_UsPhoneFormatter()],
      onBack: onBack,
      onSendCode: (phone) async {
        String formattedPhone = phone.trim().replaceAll(RegExp(r'[-\s()]'), '');
        if (!formattedPhone.startsWith('+')) {
          formattedPhone = '+$formattedPhone';
        }
        
        final result = await privy.sms.sendCode(formattedPhone);
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
        String formattedPhone = phone.trim().replaceAll(RegExp(r'[-\s()]'), '');
        if (!formattedPhone.startsWith('+')) {
          formattedPhone = '+$formattedPhone';
        }

        final result = await privy.sms.loginWithCode(
          code: code,
          phoneNumber: formattedPhone,
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

class _UsPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    String actualDigits = digits;
    if (digits.isEmpty) {
      actualDigits = '1';
    } else if (!digits.startsWith('1')) {
      actualDigits = '1$digits';
    }
    
    if (actualDigits.length > 11) {
      actualDigits = actualDigits.substring(0, 11);
    }
    
    final buffer = StringBuffer('+1');
    if (actualDigits.length > 1) {
      buffer.write(' ');
    }
    
    for (int i = 1; i < actualDigits.length; i++) {
      if (i == 4 || i == 7) {
        buffer.write(' ');
      }
      buffer.write(actualDigits[i]);
    }
    
    final newText = buffer.toString();
    
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
