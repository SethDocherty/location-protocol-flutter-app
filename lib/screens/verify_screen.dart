import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';

import '../protocol/attestation_service.dart';
import '../utils/attestation_json.dart';

/// Screen for verifying an offchain attestation from pasted JSON.
class VerifyScreen extends StatefulWidget {
  final AttestationService service;

  const VerifyScreen({super.key, required this.service});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _jsonController = TextEditingController();
  bool _verifying = false;
  VerificationResult? _result;
  String? _claimedSigner;
  String? _error;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _result = null;
      _claimedSigner = null;
      _error = null;
    });

    try {
      final jsonText = _jsonController.text.trim();
      final attestation = decodeSignedOffchainAttestationJson(jsonText);
      _claimedSigner = attestation.signer;

      final result = widget.service.verifyOffchain(attestation);

      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Attestation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste canonical EAS offchain attestation JSON to verify it.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jsonController,
              decoration: const InputDecoration(
                labelText: 'Attestation JSON',
                border: OutlineInputBorder(),
                hintText:
                    '{"signer":"0x...","sig":{"domain":{...},"primaryType":"Attest",...}}',
              ),
              maxLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _verifying ? null : _verify,
              child: _verifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify'),
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
            if (_result != null) ...[
              const SizedBox(height: 16),
              _buildResultCard(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = _result!.isValid;

    return Card(
      color: isValid
          ? Colors.green.withValues(alpha: 0.1)
          : Colors.red.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.cancel,
                  color: isValid ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isValid ? 'VALID' : 'INVALID',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isValid ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(),
            _infoRow('Recovered Address', _result!.recoveredAddress),
            if (_claimedSigner != null)
              _infoRow('Claimed Signer', _claimedSigner!),
            if (_result!.reason != null) _infoRow('Reason', _result!.reason!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
