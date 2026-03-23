

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_wallet_provider.dart';

import '../protocol/attestation_service.dart';
import '../protocol/schema_config.dart';
import '../utils/network_links.dart';

/// Screen for registering the app's EAS schema onchain.
class RegisterSchemaScreen extends StatefulWidget {
  final AttestationService service;
  const RegisterSchemaScreen({
    super.key,
    required this.service,
  });

  @override
  State<RegisterSchemaScreen> createState() => _RegisterSchemaScreenState();
}

class _RegisterSchemaScreenState extends State<RegisterSchemaScreen> {
  bool _checking = true;
  bool _isRegistered = false;
  bool _submitting = false;
  String? _txHash;
  Map<String, dynamic>? _receipt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final exists = await widget.service.isSchemaRegistered();
      if (mounted) setState(() => _isRegistered = exists);
    } catch (e) {
      if (mounted) setState(() => _error = 'Status check failed: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _register() async {
    setState(() {
      _submitting = true;
      _txHash = null;
      _receipt = null;
      _error = null;
    });

    try {
      final callData = widget.service.buildRegisterSchemaCallData();
      final txRequest = widget.service.buildTxRequest(
        callData: callData,
        contractAddress: widget.service.schemaRegistryAddress,
      );

      final txHash = await context.read<AppWalletProvider>().sendTransaction(txRequest);
      if (txHash == null) throw Exception('Transaction cancelled or failed');

      if (mounted) setState(() => _txHash = txHash);

      // Wait for receipt to provide a premium experience
      _waitForReceipt(txHash);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _waitForReceipt(String txHash) async {
    // Poll for receipt (simple version for this demo/task)
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final receipt = await widget.service.getTransactionReceipt(txHash);
      if (receipt != null) {
        if (mounted) setState(() => _receipt = receipt);
        _checkStatus(); // Confirm registration status
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schemaString = AppSchema.definition.toEASSchemaString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Schema'),
        actions: [
          if (!_checking)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _checkStatus,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_checking) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              const Center(child: Text('Checking onchain status...')),
            ] else if (_isRegistered) ...[
              Card(
                color: Colors.blue.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This schema is already registered onchain.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (NetworkLinks.getEasScanSchemaUrl(widget.service.chainId, AppSchema.schemaUID) != null) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'View at: ${NetworkLinks.getEasScanSchemaUrl(widget.service.chainId, AppSchema.schemaUID)}',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('View Schema on EAS Scan'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
            FilledButton.icon(
              onPressed:
                  (_submitting || _checking || _isRegistered) ? null : _register,
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(
                _isRegistered ? 'Already Registered' : 'Register Schema Onchain',
              ),
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
                      Text(
                        _receipt != null
                            ? '✅ Registration Confirmed'
                            : '⏳ Transaction Submitted',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        'TX: $_txHash',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                      if (_receipt != null) ...[
                        const Divider(height: 24),
                        _receiptRow('Block', _receipt!['blockNumber']),
                        _receiptRow('Status', _receipt!['status']),
                        _receiptRow('Gas Used', _receipt!['gasUsed']),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Waiting for receipt...',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (NetworkLinks.getExplorerTxUrl(widget.service.chainId, _txHash!) != null)
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('View at: ${NetworkLinks.getExplorerTxUrl(widget.service.chainId, _txHash!)}'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Block Explorer'),
                            ),
                          if (NetworkLinks.getEasScanSchemaUrl(widget.service.chainId, AppSchema.schemaUID) != null)
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('View at: ${NetworkLinks.getEasScanSchemaUrl(widget.service.chainId, AppSchema.schemaUID)}'),
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

  Widget _receiptRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text('$value',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ],
      ),
    );
  }
}
