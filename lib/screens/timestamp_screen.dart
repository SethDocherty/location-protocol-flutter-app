import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:privy_flutter/privy_flutter.dart';

import '../protocol/attestation_service.dart';
import '../utils/network_links.dart';

/// Screen for timestamping an offchain attestation UID onchain.
class TimestampScreen extends StatefulWidget {
  final AttestationService service;
  final EmbeddedEthereumWallet wallet;

  const TimestampScreen({
    super.key,
    required this.service,
    required this.wallet,
  });

  @override
  State<TimestampScreen> createState() => _TimestampScreenState();
}

class _TimestampScreenState extends State<TimestampScreen> {
  final _uidController = TextEditingController();
  bool _submitting = false;
  String? _txHash;
  String? _error;

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = _uidController.text.trim();
    if (!uid.startsWith('0x') || uid.length != 66) {
      setState(() => _error = 'Enter a valid 0x-prefixed 32-byte hex UID');
      return;
    }

    setState(() {
      _submitting = true;
      _txHash = null;
      _error = null;
    });

    try {
      // Check if already timestamped
      final exists = await widget.service.isTimestamped(uid);
      if (exists) {
        if (mounted) {
          setState(() {
            _error = 'Error: This UID has already been timestamped onchain.';
            _submitting = false;
          });
        }
        return;
      }

      final callData = widget.service.buildTimestampCallData(uid);
      final txRequest = widget.service.buildTxRequest(
        callData: callData,
        contractAddress: widget.service.easAddress,
      );

      final result = await widget.wallet.provider.request(
        EthereumRpcRequest(method: 'eth_sendTransaction', params: [jsonEncode(txRequest)]),
      );

      String? hash;
      result.fold(
        onSuccess: (r) => hash = r.data,
        onFailure: (e) {
          final message = e.message;
          if (message.contains('0x2e267946') || message.contains('.&yF')) {
             throw Exception('This UID has already been timestamped onchain.');
          }
          throw Exception('Transaction failed: $message');
        },
      );

      if (mounted && hash != null) setState(() => _txHash = hash);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Timestamp Offchain UID')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Anchor an offchain attestation UID onchain for immutable '
              'proof of existence.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _uidController,
              decoration: const InputDecoration(
                labelText: 'Offchain UID (0x-prefixed hex)',
                hintText: '0x...',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Timestamp Onchain'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
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
                        'Timestamp Submitted',
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
                      if (NetworkLinks.getExplorerTxUrl(widget.service.chainId, _txHash!) != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'View at: ${NetworkLinks.getExplorerTxUrl(widget.service.chainId, _txHash!)}',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('View on Block Explorer'),
                        ),
                      ],
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
