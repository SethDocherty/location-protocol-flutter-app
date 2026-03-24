

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_wallet_provider.dart';

import '../protocol/attestation_service.dart';
import '../utils/network_links.dart';

/// Screen for creating an onchain attestation via the Privy wallet.
///
/// Uses the static builder pipeline:
/// EASClient.buildAttestCallData → TxUtils.buildTxRequest → eth_sendTransaction
class OnchainAttestScreen extends StatefulWidget {
  final AttestationService service;
  const OnchainAttestScreen({
    super.key,
    required this.service,
  });

  @override
  State<OnchainAttestScreen> createState() => _OnchainAttestScreenState();
}

class _OnchainAttestScreenState extends State<OnchainAttestScreen> {
  final _latController = TextEditingController(text: '37.7749');
  final _lngController = TextEditingController(text: '-122.4194');
  final _memoController = TextEditingController();

  bool _submitting = false;
  String? _txHash;
  String? _uid;
  String? _error;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!mounted) return;
    setState(() {
      _submitting = true;
      _txHash = null;
      _uid = null;
      _error = null;
    });

    try {
      final lat = double.parse(_latController.text.trim());
      final lng = double.parse(_lngController.text.trim());
      final memo = _memoController.text.trim();

      // Build calldata
      final callData = widget.service.buildAttestCallData(
        lat: lat,
        lng: lng,
        memo: memo.isEmpty ? 'No memo' : memo,
      );

      // Build tx request
      final txRequest = widget.service.buildTxRequest(
        callData: callData,
        contractAddress: widget.service.easAddress,
      );

      // Send via AppWalletProvider
      final hash = await context.read<AppWalletProvider>().sendTransaction(
        txRequest,
        context: context,
      );

      if (hash != null) {
        if (mounted) {
          setState(() {
            _txHash = hash;
          });
        }
        
        // Wait for the UID
        final uid = await widget.service.waitForAttestationUid(hash);
        if (mounted) setState(() => _uid = uid);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onchain Attestation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create an onchain attestation. This submits a transaction '
              'and requires gas.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: 'Memo (optional)',
                border: OutlineInputBorder(),
              ),
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
                  : const Text('Submit Onchain Attestation'),
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
                        'Transaction Submitted',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        'TX Hash: $_txHash',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      if (_uid != null) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          'Attestation UID: $_uid',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 16),
                            Text('Waiting for transaction to be mined...'),
                          ]
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (NetworkLinks.getExplorerTxUrl(widget.service.chainId, _txHash!) != null)
                            TextButton.icon(
                              onPressed: () {
                                // In a real app, launch URL. For now, copy/toast.
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('View at: ${NetworkLinks.getExplorerTxUrl(widget.service.chainId, _txHash!)}'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Block Explorer'),
                            ),
                          if (_uid != null && NetworkLinks.getEasScanAttestationUrl(widget.service.chainId, _uid!) != null)
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('View at: ${NetworkLinks.getEasScanAttestationUrl(widget.service.chainId, _uid!)}'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('EAS Scan'),
                            ),
                        ],
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
