import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';

import '../protocol/attestation_service.dart';

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
      final attestation = _parseAttestation(jsonText);
      _claimedSigner = attestation.signer;

      final result = widget.service.verifyOffchain(attestation);

      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Parses JSON into a [SignedOffchainAttestation].
  ///
  /// Supports the library's model format with fields:
  /// uid, schemaUID, recipient, time, expirationTime, revocable,
  /// refUID, data (hex), salt (hex), version, signature {v, r, s}, signer.
  SignedOffchainAttestation _parseAttestation(String jsonText) {
    final map = jsonDecode(jsonText) as Map<String, dynamic>;

    // Parse hex data field to Uint8List
    final dataHex = map['data'] as String;
    final dataClean = dataHex.startsWith('0x') ? dataHex.substring(2) : dataHex;
    final data = Uint8List.fromList([
      for (var i = 0; i < dataClean.length; i += 2)
        int.parse(dataClean.substring(i, i + 2), radix: 16),
    ]);

    final sigMap = map['signature'] as Map<String, dynamic>;

    return SignedOffchainAttestation(
      uid: map['uid'] as String,
      schemaUID: map['schemaUID'] as String,
      recipient: map['recipient'] as String,
      time: BigInt.from(map['time'] as int),
      expirationTime: BigInt.from(map['expirationTime'] as int),
      revocable: map['revocable'] as bool,
      refUID: map['refUID'] as String,
      data: data,
      salt: map['salt'] as String,
      version: map['version'] as int,
      signature: EIP712Signature(
        v: sigMap['v'] as int,
        r: sigMap['r'] as String,
        s: sigMap['s'] as String,
      ),
      signer: map['signer'] as String,
    );
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
            const Text('Paste a signed attestation JSON to verify it.'),
            const SizedBox(height: 12),
            TextField(
              controller: _jsonController,
              decoration: const InputDecoration(
                labelText: 'Attestation JSON',
                border: OutlineInputBorder(),
                hintText: '{"uid":"0x...","schemaUID":"0x...",...}',
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
