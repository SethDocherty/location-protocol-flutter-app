import 'dart:convert';

import 'package:flutter/material.dart';

import '../src/eas/eip712_signer.dart';
import '../src/models/location_attestation.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _jsonController = TextEditingController();
  bool _verifying = false;
  _VerifyResult? _result;
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
      _error = null;
    });

    try {
      final raw = _jsonController.text.trim();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      
      final OffchainLocationAttestation attestation;
      
      // Detect if it's EAS format (has 'sig' field) or our internal flat format
      if (map.containsKey('sig')) {
        attestation = OffchainLocationAttestation.fromEasOffchainJson(map);
      } else {
        attestation = OffchainLocationAttestation.fromJson(map);
      }

      final recovered = EIP712Signer.recoverSigner(attestation: attestation);
      final isValid = recovered != null &&
          recovered.toLowerCase() == attestation.signer.toLowerCase();

      setState(() {
        _result = _VerifyResult(
          attestation: attestation,
          recoveredAddress: recovered ?? '(recovery failed)',
          isValid: isValid,
        );
        _verifying = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Attestation'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _jsonController,
                decoration: const InputDecoration(
                  labelText: 'Signed attestation JSON',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  hintText: '{ "sig": { ... }, "signer": "0x..." }',
                ),
                maxLines: 8,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: _verifying
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.verified),
                label: const Text('Verify'),
                onPressed: _verifying ? null : _verify,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              ],
              if (_result != null) ...[
                const SizedBox(height: 24),
                _VerifyCard(result: _result!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifyResult {
  final OffchainLocationAttestation attestation;
  final String recoveredAddress;
  final bool isValid;

  const _VerifyResult({
    required this.attestation,
    required this.recoveredAddress,
    required this.isValid,
  });
}

class _VerifyCard extends StatelessWidget {
  final _VerifyResult result;

  const _VerifyCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final att = result.attestation;
    final isValid = result.isValid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isValid ? Icons.verified_user : Icons.gpp_bad,
                  color: isValid
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  isValid ? '✅ Valid Signature' : '❌ Invalid Signature',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isValid
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const Divider(),
            const _Label('Recovered address'),
            SelectableText(result.recoveredAddress,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace')),
            const SizedBox(height: 8),
            const _Label('Claimed signer'),
            SelectableText(att.signer,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace')),
            const Divider(),
            const _Label('Location'),
            SelectableText(att.location,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace')),
            const SizedBox(height: 4),
            const _Label('Timestamp'),
            Text(
              DateTime.fromMillisecondsSinceEpoch(att.eventTimestamp * 1000)
                  .toUtc()
                  .toIso8601String(),
              style: theme.textTheme.bodySmall,
            ),
            if (att.memo != null) ...[
              const SizedBox(height: 4),
              const _Label('Memo'),
              Text(att.memo!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 4),
            const _Label('UID'),
            SelectableText(att.uid,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
    );
  }
}
