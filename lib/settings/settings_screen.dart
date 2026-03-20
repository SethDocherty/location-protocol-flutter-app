import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';

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
      _keyController.text = service.privateKeyHex;
      _chainId = service.selectedChainId;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_service == null) return;
    await _service!.setRpcUrl(_rpcController.text.trim());
    await _service!.setSelectedChainId(_chainId);
    final key = _keyController.text.trim();
    if (key.isNotEmpty) {
      await _service!.setPrivateKeyHex(key);
    } else {
      await _service!.clearPrivateKey();
    }
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
                    'These settings are used for the private-key onchain path '
                    'and for connecting to an RPC node. Not required for '
                    'Privy-wallet operations.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ChainSelector(
                    selectedChainId: _chainId,
                    onChanged: (id) => setState(() => _chainId = id),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _rpcController,
                    decoration: const InputDecoration(
                      labelText: 'RPC URL',
                      hintText: 'https://eth-sepolia.g.alchemy.com/v2/...',
                      border: OutlineInputBorder(),
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
