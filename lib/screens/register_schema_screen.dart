import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:privy_flutter/privy_flutter.dart';

import '../protocol/attestation_service.dart';
import '../protocol/schema_config.dart';

/// Screen for registering the app's EAS schema onchain.
class RegisterSchemaScreen extends StatefulWidget {
  final AttestationService service;
  final EmbeddedEthereumWallet wallet;

  const RegisterSchemaScreen({
    super.key,
    required this.service,
    required this.wallet,
  });

  @override
  State<RegisterSchemaScreen> createState() => _RegisterSchemaScreenState();
}

class _RegisterSchemaScreenState extends State<RegisterSchemaScreen> {
  bool _submitting = false;
  String? _txHash;
  String? _error;

  Future<void> _register() async {
    setState(() {
      _submitting = true;
      _txHash = null;
      _error = null;
    });

    try {
      final callData = widget.service.buildRegisterSchemaCallData();
      final txRequest = widget.service.buildTxRequest(
        callData: callData,
        contractAddress: widget.service.schemaRegistryAddress,
      );

      final result = await widget.wallet.provider.request(
        EthereumRpcRequest(method: 'eth_sendTransaction', params: [txRequest]),
      );

      late String txHash;
      result.fold(
        onSuccess: (r) => txHash = r.data,
        onFailure: (e) => throw Exception('Transaction failed: ${e.message}'),
      );

      if (mounted) setState(() => _txHash = txHash);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schemaString = AppSchema.definition.toEASSchemaString();

    return Scaffold(
      appBar: AppBar(title: const Text('Register Schema')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Schema String',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                schemaString,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Schema UID',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: AppSchema.schemaUID));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Schema UID copied')),
                    );
                  },
                ),
              ],
            ),
            SelectableText(
              AppSchema.schemaUID,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _register,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Register Schema Onchain'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!),
                ),
              ),
            ],
            if (_txHash != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Schema Registration Submitted',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        'TX Hash: $_txHash',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
