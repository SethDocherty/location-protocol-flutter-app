import 'package:flutter/material.dart';

import '../widgets/chain_selector.dart';
import 'settings_service.dart';

/// Settings screen for dev/test configuration.
///
/// Allows configuring: RPC URL, chain ID, and a private key for
/// the private-key onchain path.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _rpcController = TextEditingController();
  final _keyController = TextEditingController();
  final _infuraKeyController = TextEditingController();
  int _chainId = 11155111;
  bool _loading = true;
  SettingsService? _service;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = await SettingsService.create();
    if (!mounted) return;
    setState(() {
      _service = service;
      _rpcController.text = service.rpcUrl;
      _infuraKeyController.text = service.infuraApiKey;
      _keyController.text = service.privateKeyHex;
      _chainId = service.selectedChainId;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_service == null) return;

    final rawKey = _keyController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (rawKey.isNotEmpty) {
      // Validate key format
      var checkKey = rawKey;
      if (checkKey.startsWith('0x')) checkKey = checkKey.substring(2);

      if (checkKey.length != 64 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(checkKey)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Invalid Private Key (must be a 64-character hex string)',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
      await _service!.setPrivateKeyHex(rawKey);
    } else {
      await _service!.clearPrivateKey();
    }

    await _service!.setRpcUrl(_rpcController.text.trim());
    await _service!.setSelectedChainId(_chainId);
    await _service!.setInfuraApiKey(_infuraKeyController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  void dispose() {
    _keyController.clear(); // Clear sensitive data
    _rpcController.dispose();
    _keyController.dispose();
    _infuraKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Developer / Test Configuration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The RPC URL is used for onchain status checks and '
                    'transaction verification. This is required for schema '
                    'registration checks if your wallet provider (like Privy) '
                    'does not support read-only eth_call methods.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ChainSelector(
                    selectedChainId: _chainId,
                    onChanged: (id) => setState(() => _chainId = id),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _infuraKeyController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Infura API Key',
                      hintText: 'Enter your Infura API Key...',
                      border: const OutlineInputBorder(),
                      enabled: SettingsService.isChainSupported(_chainId),
                      helperText: SettingsService.isChainSupported(_chainId)
                          ? 'Automates RPC URL for supported networks'
                          : 'Not supported for this network',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (SettingsService.getInfuraUrl(
                        _chainId,
                        _infuraKeyController.text.trim(),
                      ) !=
                      null) ...[
                    const Text(
                      'RPC Managed by Infura',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _rpcController,
                    enabled: SettingsService.getInfuraUrl(
                          _chainId,
                          _infuraKeyController.text.trim(),
                        ) ==
                        null,
                    decoration: InputDecoration(
                      labelText: 'RPC URL',
                      hintText: SettingsService.getInfuraUrl(
                            _chainId,
                            _infuraKeyController.text.trim(),
                          ) ??
                          'https://eth-sepolia.g.alchemy.com/v2/...',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      labelText: 'Private Key (hex, for dev/test only)',
                      hintText: 'ac0974bec39a17e36ba4a6b4d238ff944bacb478...',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    maxLength: 66,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Save Settings'),
                  ),
                ],
              ),
            ),
    );
  }
}
