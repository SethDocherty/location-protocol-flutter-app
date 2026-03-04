import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../src/wallet/attestation_wallet.dart';

class WalletScreen extends StatefulWidget {
  final AttestationWallet wallet;

  const WalletScreen({super.key, required this.wallet});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String? _address;
  bool _loading = false;
  bool _showImport = false;
  final _importController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    final addr = await widget.wallet.getAddress();
    if (mounted) setState(() => _address = addr);
  }

  Future<void> _generateWallet() async {
    setState(() => _loading = true);
    try {
      final addr = await widget.wallet.generateNewWallet();
      if (mounted) {
        setState(() {
          _address = addr;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New wallet generated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _importKey() async {
    final hexKey = _importController.text.trim();
    if (hexKey.isEmpty) return;
    setState(() => _loading = true);
    try {
      final addr = await widget.wallet.importPrivateKey(hexKey);
      if (mounted) {
        setState(() {
          _address = addr;
          _loading = false;
          _showImport = false;
          _importController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Private key imported!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid key: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Address display
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Ethereum Address',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_address != null) ...[
                        SelectableText(
                          _address!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Address'),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _address!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Address copied!')),
                            );
                          },
                        ),
                      ] else
                        Text('No wallet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.error,
                            )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Generate button
              FilledButton.icon(
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.generating_tokens),
                label: const Text('Generate New Wallet'),
                onPressed: _loading ? null : _generateWallet,
              ),
              const SizedBox(height: 12),

              // Import key section
              OutlinedButton.icon(
                icon: Icon(_showImport ? Icons.expand_less : Icons.key),
                label: Text(_showImport ? 'Cancel' : 'Import Private Key'),
                onPressed: () =>
                    setState(() => _showImport = !_showImport),
              ),
              if (_showImport) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _importController,
                  decoration: const InputDecoration(
                    labelText: 'Private key (hex)',
                    hintText: '0xac0974bec39a...',
                    border: OutlineInputBorder(),
                    helperText:
                        'Enter a 32-byte secp256k1 private key in hex',
                  ),
                  keyboardType: TextInputType.text,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _loading ? null : _importKey,
                  child: const Text('Import'),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '⚠️  Private keys are stored in Android Keystore-backed secure storage. '
                'Never share your private key.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
