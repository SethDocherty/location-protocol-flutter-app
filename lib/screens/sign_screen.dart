import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';

import '../protocol/attestation_service.dart';
import '../widgets/attestation_result_card.dart';

/// Screen for signing an offchain location attestation.
class SignScreen extends StatefulWidget {
  final AttestationService service;

  const SignScreen({super.key, required this.service});

  @override
  State<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends State<SignScreen> {
  final _latController = TextEditingController(text: '37.7749');
  final _lngController = TextEditingController(text: '-122.4194');
  final _memoController = TextEditingController();

  bool _signing = false;
  SignedOffchainAttestation? _result;
  String? _error;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _sign() async {
    setState(() {
      _signing = true;
      _result = null;
      _error = null;
    });

    try {
      final lat = double.parse(_latController.text.trim());
      final lng = double.parse(_lngController.text.trim());
      final memo = _memoController.text.trim();

      final signed = await widget.service.signOffchain(
        lat: lat,
        lng: lng,
        memo: memo.isEmpty ? 'No memo' : memo,
      );

      if (mounted) setState(() => _result = signed);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Offchain Attestation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              onPressed: _signing ? null : _sign,
              child: _signing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign Attestation'),
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
              AttestationResultCard(attestation: _result!),
            ],
          ],
        ),
      ),
    );
  }
}
