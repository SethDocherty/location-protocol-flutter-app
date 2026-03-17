/// Bottom-sheet dialog for importing an Ethereum private key and creating a
/// [LocalKeySigner] that lives only in memory for the current session.
///
/// The key is never persisted to disk or transmitted anywhere.
library;

import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';

import 'local_key_signer.dart';

/// Shows a private-key import bottom sheet.
///
/// Returns a [LocalKeySigner] on success, or null if the user cancels.
Future<LocalKeySigner?> showPrivateKeyImportDialog(
  BuildContext context,
) {
  return showModalBottomSheet<LocalKeySigner>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PrivateKeyImportSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _PrivateKeyImportSheet extends StatefulWidget {
  const _PrivateKeyImportSheet();

  @override
  State<_PrivateKeyImportSheet> createState() => _PrivateKeyImportSheetState();
}

class _PrivateKeyImportSheetState extends State<_PrivateKeyImportSheet> {
  final _controller = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    final hex = raw.startsWith('0x') ? raw.substring(2) : raw;

    if (hex.isEmpty) {
      setState(() => _error = 'Please enter a private key.');
      return;
    }
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex)) {
      setState(() => _error =
          'Private key must be exactly 32 bytes (64 hex characters). '
          'Got ${hex.length}.');
      return;
    }

    try {
      final privateKey = EthPrivateKey.fromHex(hex);
      Navigator.of(context).pop(LocalKeySigner(privateKey));
    } catch (e) {
      setState(() => _error = 'Invalid private key: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = _controller.text;
    final hex = raw.startsWith('0x') ? raw.substring(2) : raw;
    final charCount = hex.length;
    final isValid = charCount == 64 &&
        RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title ─────────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.key, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Sign with Private Key',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Security warning ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: theme.colorScheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your key is used only in memory and never stored or '
                    'transmitted. Do not use a key that holds significant funds.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Key input ─────────────────────────────────────────────────────
          TextField(
            controller: _controller,
            obscureText: _obscure,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'Private key (hex)',
              hintText: '0x… or 64 hex characters',
              border: const OutlineInputBorder(),
              errorText: _error,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Character counter
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '$charCount/64',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isValid
                            ? Colors.green
                            : (charCount > 0 ? Colors.red : null),
                      ),
                    ),
                  ),
                  // Visibility toggle
                  IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    tooltip: _obscure ? 'Show key' : 'Hide key',
                  ),
                ],
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),

          // ── Actions ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Sign Attestation'),
                  onPressed: isValid ? _submit : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
