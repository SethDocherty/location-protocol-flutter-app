/// A reusable two-step OTP input view for SMS and Email auth flows.
///
/// Step 1: User enters identifier (phone/email) + taps "Send Code".
/// Step 2: User enters 6-digit OTP + taps "Verify".
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callback signatures for OTP operations.
typedef SendCodeCallback = Future<bool> Function(String identifier);
typedef VerifyCodeCallback = Future<bool> Function(String code, String identifier);

/// A two-step OTP input view shared by SMS and Email auth flows.
class OtpInputView extends StatefulWidget {
  /// Label for the identifier field (e.g., "Phone number", "Email address").
  final String identifierLabel;

  /// Hint text for the identifier field.
  final String identifierHint;

  /// Keyboard type for the identifier field.
  final TextInputType identifierKeyboardType;

  /// Called with the identifier to send a verification code.
  /// Returns true if the code was sent successfully.
  final SendCodeCallback onSendCode;

  /// Called with the code and identifier to verify.
  /// Returns true if verification succeeded.
  final VerifyCodeCallback onVerifyCode;

  /// Called when the user taps the back arrow.
  final VoidCallback onBack;

  /// Optional input formatters for the identifier field.
  final List<TextInputFormatter>? identifierInputFormatters;

  /// Optional initial value for the identifier field.
  final String? initialIdentifier;

  const OtpInputView({
    super.key,
    required this.identifierLabel,
    required this.identifierHint,
    required this.identifierKeyboardType,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.onBack,
    this.identifierInputFormatters,
    this.initialIdentifier,
  });

  @override
  State<OtpInputView> createState() => _OtpInputViewState();
}

class _OtpInputViewState extends State<OtpInputView> {
  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialIdentifier != null) {
      _identifierController.text = widget.initialIdentifier!;
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(
        () => _error =
            'Please enter your ${widget.identifierLabel.toLowerCase()}',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final success = await widget.onSendCode(identifier);
      if (mounted) {
        setState(() {
          _codeSent = success;
          _loading = false;
          if (!success) _error = 'Failed to send code. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter the verification code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final success = await widget.onVerifyCode(
        code,
        _identifierController.text.trim(),
      );
      if (mounted && !success) {
        setState(() {
          _loading = false;
          _error = 'Invalid code. Please try again.';
        });
      }
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
                widget.identifierLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _identifierController,
          decoration: InputDecoration(
            labelText: widget.identifierLabel,
            hintText: widget.identifierHint,
            border: const OutlineInputBorder(),
          ),
          keyboardType: widget.identifierKeyboardType,
          inputFormatters: widget.identifierInputFormatters,
          autocorrect: false,
          enabled: !_codeSent || !_loading,
        ),
        const SizedBox(height: 12),
        if (!_codeSent) ...[
          FilledButton(
            onPressed: _loading ? null : _sendCode,
            child: _loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send Code'),
          ),
        ],
        if (_codeSent) ...[
          const Divider(height: 32),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Verification Code',
              hintText: '123456',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: !_loading,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _verifyCode,
            child: _loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verify'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : _sendCode,
            child: const Text('Resend code'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
