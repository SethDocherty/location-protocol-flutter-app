import 'package:flutter/material.dart';

/// Shows a bottom-sheet dialog for importing a hex private key.
///
/// Returns the 64-character hex private key (without 0x prefix) or null if cancelled.
Future<String?> showPrivateKeyImportDialog(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _PrivateKeyImportSheet(),
  );
}

class _PrivateKeyImportSheet extends StatefulWidget {
  const _PrivateKeyImportSheet();

  @override
  State<_PrivateKeyImportSheet> createState() => _PrivateKeyImportSheetState();
}

class _PrivateKeyImportSheetState extends State<_PrivateKeyImportSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    // Clear the key from memory.
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    var key = _controller.text.trim();
    if (key.startsWith('0x')) key = key.substring(2);

    if (key.length != 64 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(key)) {
      setState(() => _error = 'Enter a valid 64-character hex private key');
      return;
    }

    // Return the key and immediately clear the controller.
    final result = key;
    _controller.clear();
    Navigator.of(context).pop(result);
    // Note: The caller MUST NOT persist this key to disk or logs.
    // See PRD Non-Functional Requirements: Security.
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Import Private Key',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter a 64-character hex private key. This key will NOT be stored.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Private Key (hex)',
              hintText: 'ac0974bec39a17e36ba4a6b4d238ff944bacb478...',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            obscureText: true,
            maxLength: 66, // 64 hex + optional 0x prefix
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
              FilledButton(onPressed: _submit, child: const Text('Import')),
            ],
          ),
        ],
      ),
    );
  }
}
