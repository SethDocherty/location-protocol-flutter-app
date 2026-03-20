/// Sign In With Ethereum (SIWE) authentication flow.
///
/// Two-step UI:
///   1. User enters their external wallet address → app generates a SIWE message.
///   2. User copies the message, signs it with their external wallet (EIP-191
///      personal_sign), pastes the signature → app calls `loginWithSiwe`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:privy_flutter/privy_flutter.dart';
import '../privy_auth_config.dart';
import '../privy_manager.dart';

/// SIWE login flow — generate message, sign externally, submit signature.
class SiweFlow extends StatefulWidget {
  /// Called with null on success, or a String error.
  final void Function(String? error) onComplete;

  /// Called when the user taps back to return to method selector.
  final VoidCallback onBack;

  /// Auth config supplying siweAppDomain / siweAppUri.
  final PrivyAuthConfig config;

  const SiweFlow({
    super.key,
    required this.onComplete,
    required this.onBack,
    required this.config,
  });

  @override
  State<SiweFlow> createState() => _SiweFlowState();
}

enum _SiweStep { address, sign }

/// Common external wallets shown in the picker.
const _kWalletOptions = [
  (label: 'MetaMask',     type: WalletClientType.metamask),
  (label: 'Coinbase',     type: WalletClientType.coinbaseWallet),
  (label: 'Rainbow',      type: WalletClientType.rainbow),
  (label: 'Trust',        type: WalletClientType.trust),
  (label: 'WalletConnect (other)', type: WalletClientType.other),
];

class _SiweFlowState extends State<SiweFlow> {
  final _addressController = TextEditingController();
  final _signatureController = TextEditingController();

  _SiweStep _step = _SiweStep.address;
  bool _loading = false;
  String? _error;

  WalletClientType _walletClientType = WalletClientType.metamask;

  // Set after a successful generateSiweMessage call.
  String? _siweMessage;
  SiweMessageParams? _siweParams;

  @override
  void dispose() {
    _addressController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  // ── Step 1: generate the SIWE message from the entered wallet address ──────

  Future<void> _generateMessage() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Please enter a wallet address.');
      return;
    }
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)) {
      setState(() => _error = 'Enter a valid 0x… Ethereum address.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final params = SiweMessageParams(
        appDomain: widget.config.siweAppDomain,
        appUri: widget.config.siweAppUri,
        chainId: '1',
        walletAddress: address,
      );

      final result = await PrivyManager().privy.siwe.generateSiweMessage(params);

      result.fold(
        onSuccess: (message) {
          setState(() {
            _siweMessage = message;
            _siweParams = params;
            _step = _SiweStep.sign;
            _loading = false;
          });
        },
        onFailure: (error) {
          setState(() {
            _error = error.message;
            _loading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Step 2: submit the pasted signature ────────────────────────────────────

  Future<void> _submitSignature() async {
    final signature = _signatureController.text.trim();
    if (signature.isEmpty) {
      setState(() => _error = 'Paste the signature from your wallet.');
      return;
    }

    // A valid personal_sign signature is exactly 65 bytes = 0x + 130 hex chars.
    final hex = signature.startsWith('0x') ? signature.substring(2) : signature;
    if (hex.length != 130) {
      setState(() => _error =
          'Signature must be 65 bytes (132 characters including 0x). '
          'Got ${signature.length} characters — make sure you copied the entire signature.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await PrivyManager().privy.siwe.loginWithSiwe(
        message: _siweMessage!,
        signature: signature,
        params: _siweParams!,
        metadata: WalletLoginMetadata(walletClientType: _walletClientType),
      );

      result.fold(
        onSuccess: (_) => widget.onComplete(null),
        onFailure: (error) {
          setState(() {
            _error = error.message;
            _loading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Back / title row
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _loading
                  ? null
                  : (_step == _SiweStep.sign
                      ? () => setState(() {
                            _step = _SiweStep.address;
                            _error = null;
                            _siweMessage = null;
                            _signatureController.clear();
                          })
                      : widget.onBack),
            ),
            Expanded(
              child: Text(
                'Connect Wallet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_step == _SiweStep.address) _buildAddressStep(),
        if (_step == _SiweStep.sign) _buildSignStep(),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildAddressStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter the address of your external wallet to generate a sign-in message.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Wallet address',
            hintText: '0x…',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.text,
          autocorrect: false,
          enabled: !_loading,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _generateMessage,
          child: _loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Generate Message'),
        ),
      ],
    );
  }

  Widget _buildSignStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '1. Copy the message below and sign it with your external wallet using personal_sign (EIP-191).',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          'You can sign using MetaMask → Account Options → Sign Message, '
          'or any wallet that supports EIP-191 personal_sign.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 8),
        // Copyable message box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              SelectableText(
                _siweMessage!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy message',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _siweMessage!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Wallet type picker
        DropdownButtonFormField<WalletClientType>(
          initialValue: _walletClientType,
          decoration: const InputDecoration(
            labelText: 'Wallet used to sign',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final opt in _kWalletOptions)
              DropdownMenuItem(
                value: opt.type,
                child: Text(opt.label),
              ),
          ],
          onChanged: _loading
              ? null
              : (v) => setState(() => _walletClientType = v!),
        ),
        const SizedBox(height: 16),
        Text(
          '2. Paste the full 65-byte signature here (0x + 130 hex chars = 132 chars total).',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _signatureController,
          builder: (context, value, _) {
            final len = value.text.trim().length;
            final isCorrectLength = len == 132;
            final counterColor = len == 0
                ? theme.colorScheme.outline
                : isCorrectLength
                    ? Colors.green
                    : theme.colorScheme.error;
            return TextField(
              controller: _signatureController,
              decoration: InputDecoration(
                labelText: 'Signature',
                hintText: '0x…',
                border: const OutlineInputBorder(),
                helperText: len == 0
                    ? 'Expected 132 characters'
                    : isCorrectLength
                        ? '✓ Correct length'
                        : '$len / 132 characters',
                helperStyle: TextStyle(color: counterColor),
              ),
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              enabled: !_loading,
            );
          },
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _submitSignature,
          child: _loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Sign In'),
        ),
      ],
    );
  }
}
