import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location_protocol/location_protocol.dart';

/// Shows a bottom-sheet dialog for external wallet signing.
///
/// Displays the typed data JSON for the user to copy and sign externally,
/// then accepts the pasted 65-byte hex signature.
///
/// Returns an [EIP712Signature] or null if cancelled.
Future<EIP712Signature?> showExternalSignDialog(
  BuildContext context,
  Map<String, dynamic> typedData,
) {
  return showModalBottomSheet<EIP712Signature>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ExternalSignSheet(typedData: typedData),
  );
}

class _ExternalSignSheet extends StatefulWidget {
  final Map<String, dynamic> typedData;

  const _ExternalSignSheet({required this.typedData});

  @override
  State<_ExternalSignSheet> createState() => _ExternalSignSheetState();
}

class _ExternalSignSheetState extends State<_ExternalSignSheet> {
  final _sigController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  void _copyTypedData() {
    final json = const JsonEncoder.withIndent('  ').convert(widget.typedData);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Typed data copied to clipboard')),
    );
  }

  void _submit() {
    final sigHex = _sigController.text.trim();

    try {
      final sig = EIP712Signature.fromHex(sigHex);
      Navigator.of(context).pop(sig);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jsonStr = const JsonEncoder.withIndent(
      '  ',
    ).convert(widget.typedData);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'Sign with External Wallet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Copy the typed data below\n'
                '2. Sign it with your wallet (e.g., MetaMask → eth_signTypedData_v4)\n'
                '3. Paste the 65-byte hex signature',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EIP-712 Typed Data',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  IconButton(
                    onPressed: _copyTypedData,
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy typed data',
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  jsonStr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sigController,
                decoration: InputDecoration(
                  labelText: 'Signature (65-byte hex)',
                  hintText: '0x...',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                maxLines: 2,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Submit Signature'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
