import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../src/builder/attestation_builder.dart';
import '../src/eas/attestation_signer.dart';
import '../src/eas/eip712_signer.dart';
import '../src/models/location_attestation.dart';

class SignScreen extends StatefulWidget {
  final AttestationSigner signer;

  const SignScreen({super.key, required this.signer});

  @override
  State<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<SignScreen> {
  final _latController =
      TextEditingController(text: '37.7749');
  final _lngController =
      TextEditingController(text: '-122.4194');
  final _memoController =
      TextEditingController(text: 'Test attestation');

  bool _signing = false;
  OffchainLocationAttestation? _result;
  String? _error;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _buildAndSign() async {
    setState(() {
      _signing = true;
      _result = null;
      _error = null;
    });

    try {
      final lat = double.parse(_latController.text.trim());
      final lng = double.parse(_lngController.text.trim());
      final memo = _memoController.text.trim();

      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: lat,
        longitude: lng,
        memo: memo.isEmpty ? null : memo,
      );

      final signed = await EIP712Signer.signLocationAttestationWith(
        attestation: unsigned,
        signer: widget.signer,
      );

      setState(() {
        _result = signed;
        _signing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _signing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Attestation'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Input fields
              TextField(
                controller: _latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  border: OutlineInputBorder(),
                  hintText: '37.7749',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lngController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  border: OutlineInputBorder(),
                  hintText: '-122.4194',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: 'Memo (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              FilledButton.icon(
                icon: _signing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.draw),
                label: const Text('Build & Sign'),
                onPressed: _signing ? null : _buildAndSign,
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ],

              if (_result != null) ...[
                const SizedBox(height: 24),
                _ResultCard(attestation: _result!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final OffchainLocationAttestation attestation;

  const _ResultCard({required this.attestation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sig = attestation.parsedSignature;
    final fullJson = attestation.toEasOffchainJsonString(pretty: true);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Signed Attestation',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            _Field('UID', attestation.uid),
            _Field('Signer', attestation.signer),
            _Field('v', '${sig['v']}'),
            _Field('r', '${sig['r']}'),
            _Field('s', '${sig['s']}'),
            _Field('Location', attestation.location),
            _Field(
                'Timestamp',
                DateTime.fromMillisecondsSinceEpoch(
                        attestation.eventTimestamp * 1000)
                    .toUtc()
                    .toIso8601String()),
            if (attestation.memo != null) _Field('Memo', attestation.memo!),
            const SizedBox(height: 12),
            const Divider(),
            Text('EAS Offchain JSON',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                fullJson,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy JSON'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: fullJson));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('EAS Attestation JSON copied to clipboard!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              )),
          SelectableText(
            value,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
