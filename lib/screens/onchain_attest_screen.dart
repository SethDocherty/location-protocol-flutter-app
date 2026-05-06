import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:provider/provider.dart';

import '../protocol/attestation_service.dart';
import '../providers/app_wallet_provider.dart';
import '../providers/schema_provider.dart';
import '../utils/schema_field_input_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/network_links.dart';

/// Screen for creating an onchain attestation via the Privy wallet.
class OnchainAttestScreen extends StatefulWidget {
  final AttestationService service;
  const OnchainAttestScreen({super.key, required this.service});

  @override
  State<OnchainAttestScreen> createState() => _OnchainAttestScreenState();
}

class _OnchainAttestScreenState extends State<OnchainAttestScreen> {
  final _latController = TextEditingController(text: '37.7749');
  final _lngController = TextEditingController(text: '-122.4194');
  final Map<String, TextEditingController> _controllers = {};

  bool _submitting = false;
  String? _txHash;
  String? _uid;
  String? _error;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers(List<SchemaField> fields) {
    final currentNames = fields.map((f) => f.name).toSet();
    _controllers.removeWhere((name, controller) {
      if (!currentNames.contains(name)) {
        controller.dispose();
        return true;
      }
      return false;
    });
    for (final field in fields) {
      _controllers.putIfAbsent(field.name, () => TextEditingController());
    }
  }

  Map<String, dynamic> _buildUserData(List<SchemaField> fields) {
    final Map<String, dynamic> data = {};
    for (final field in fields) {
      final val = _controllers[field.name]?.text.trim() ?? '';
      data[field.name] = parseSchemaFieldInput(field, val);
    }
    return data;
  }

  Future<void> _submit(
    SchemaDefinition definition,
    List<SchemaField> fields,
  ) async {
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
      final userData = _buildUserData(fields);

      // Build calldata
      final callData = widget.service.buildAttestCallDataWithUserData(
        schema: definition,
        lat: lat,
        lng: lng,
        userData: userData,
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
        if (mounted) setState(() => _txHash = hash);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      // Unblock the button as soon as we have a result (hash or error).
      if (mounted) setState(() => _submitting = false);
    }

    // Poll for the UID independently — the button is already re-enabled.
    final hash = _txHash;
    if (hash != null) {
      _pollForUid(hash);
    }
  }

  Future<void> _pollForUid(String hash) async {
    try {
      final uid = await widget.service.waitForAttestationUid(hash);
      if (mounted) setState(() => _uid = uid);
    } catch (e) {
      // Silently ignore UID polling failures — the TX hash card is already
      // visible and the user can manually look up the attestation.
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SchemaProvider>();
    final fields = provider.userFields;
    _syncControllers(fields);

    return Scaffold(
      appBar: AppBar(title: const Text('Onchain Attestation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
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
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Schema Fields',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            ...fields.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextField(
                  controller: _controllers[f.name],
                  decoration: InputDecoration(
                    labelText: f.name,
                    helperText: f.type,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting
                  ? null
                  : () => _submit(provider.definition, fields),
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
              _buildTxFeedback(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTxFeedback() {
    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaction Submitted',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'TX Hash: $_txHash',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            if (_uid != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                'Attestation UID: $_uid',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ] else ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Text('Waiting for transaction to be mined...'),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                if (NetworkLinks.getExplorerTxUrl(
                      widget.service.chainId,
                      _txHash!,
                    ) !=
                    null)
                  TextButton.icon(
                    onPressed: () {
                      final url = NetworkLinks.getExplorerTxUrl(
                        widget.service.chainId,
                        _txHash!,
                      );
                      if (url != null) {
                        launchUrl(Uri.parse(url));
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Block Explorer'),
                  ),
                if (_uid != null &&
                    NetworkLinks.getEasScanAttestationUrl(
                          widget.service.chainId,
                          _uid!,
                        ) !=
                        null)
                  TextButton.icon(
                    onPressed: () {
                      final url = NetworkLinks.getEasScanAttestationUrl(
                        widget.service.chainId,
                        _uid!,
                      );
                      if (url != null) {
                        launchUrl(Uri.parse(url));
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('EAS Scan'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
