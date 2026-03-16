/// Bottom-sheet dialog that walks an external-wallet user through signing an
/// EIP-712 message with MetaMask (or any browser wallet) via the console.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a modal bottom sheet that:
///   1. Displays a ready-to-run MetaMask browser-console JS snippet.
///   2. Collects the pasted signature from the user.
///
/// Returns the 0x-prefixed hex signature string, or throws if the user cancels.
Future<String> showExternalSignDialog(
  BuildContext context, {
  required String walletAddress,
  required String jsonTypedData,
}) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ExternalSignSheet(
      walletAddress: walletAddress,
      jsonTypedData: jsonTypedData,
    ),
  );
  if (result == null) throw Exception('Signing cancelled.');
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────

class _ExternalSignSheet extends StatefulWidget {
  final String walletAddress;
  final String jsonTypedData;

  const _ExternalSignSheet({
    required this.walletAddress,
    required this.jsonTypedData,
  });

  @override
  State<_ExternalSignSheet> createState() => _ExternalSignSheetState();
}

class _ExternalSignSheetState extends State<_ExternalSignSheet> {
  final _sigController = TextEditingController();
  String? _error;

  // Pretty-print the JSON so it's human readable in the scrollable block.
  late final String _prettyJson =
      const JsonEncoder.withIndent('  ').convert(jsonDecode(widget.jsonTypedData));

  String get _jsSnippet => '''// Run in your browser's MetaMask console
await ethereum.request({ method: 'eth_requestAccounts' });
const sig = await ethereum.request({
  method: 'eth_signTypedData_v4',
  params: [
    '${widget.walletAddress}',
    \`${widget.jsonTypedData}\`
  ]
});
console.log(sig);''';

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _sigController.text.trim();
    final hex = raw.startsWith('0x') ? raw.substring(2) : raw;
    if (hex.length != 130) {
      setState(() => _error =
          'Signature must be 65 bytes (132 chars incl. 0x). '
          'Got ${raw.length}.');
      return;
    }
    Navigator.of(context).pop(raw.startsWith('0x') ? raw : '0x$raw');
  }

  Widget _copyableBlock(BuildContext context, String label, String content) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied!')),
                );
              },
            ),
          ],
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 160),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Text(
              content,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sigHex = _sigController.text.startsWith('0x')
        ? _sigController.text.substring(2)
        : _sigController.text;
    final sigLen = _sigController.text.isEmpty ? 0 : sigHex.length;
    final sigOk = sigLen == 130;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────────────────────
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

            // ── Title ───────────────────────────────────────────────────────
            Text(
              'Sign with External Wallet',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.walletAddress,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),

            // ── Step 1: JS snippet ───────────────────────────────────────────
            Text(
              '1. Copy and run in your browser console (MetaMask must be connected)',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _copyableBlock(context, 'MetaMask JS snippet', _jsSnippet),
            const SizedBox(height: 8),
            // Also offer just the raw typed data for wallets supporting it directly
            _copyableBlock(context, 'Typed-data JSON (advanced)', _prettyJson),
            const SizedBox(height: 20),

            // ── Step 2: paste signature ──────────────────────────────────────
            Text(
              '2. Paste the signature from console.log output',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sigController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: '0x...',
                errorText: _error,
                suffixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    sigLen == 0
                        ? '0/130'
                        : '$sigLen/130',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: sigOk
                          ? Colors.green
                          : (sigLen > 0 ? Colors.red : null),
                    ),
                  ),
                ),
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
              onChanged: (_) => setState(() => _error = null),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // ── Actions ─────────────────────────────────────────────────────
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
                  child: FilledButton(
                    onPressed: sigOk ? _submit : null,
                    child: const Text('Submit Signature'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
