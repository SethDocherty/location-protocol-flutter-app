import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:provider/provider.dart';

import '../protocol/attestation_service.dart';
import '../providers/schema_provider.dart';
import '../utils/schema_field_input_parser.dart';
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
  final Map<String, TextEditingController> _controllers = {};

  bool _signing = false;
  SignedOffchainAttestation? _result;
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
    // Remove old controllers
    final currentNames = fields.map((f) => f.name).toSet();
    _controllers.removeWhere((name, controller) {
      if (!currentNames.contains(name)) {
        controller.dispose();
        return true;
      }
      return false;
    });

    // Add new controllers
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

  Future<void> _sign(
    SchemaDefinition definition,
    List<SchemaField> fields,
  ) async {
    setState(() {
      _signing = true;
      _result = null;
      _error = null;
    });

    try {
      final lat = double.parse(_latController.text.trim());
      final lng = double.parse(_lngController.text.trim());
      final userData = _buildUserData(fields);

      final signed = await widget.service.signOffchainWithData(
        schema: definition,
        lat: lat,
        lng: lng,
        userData: userData,
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
    final provider = context.watch<SchemaProvider>();
    final fields = provider.userFields;
    _syncControllers(fields);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Offchain Attestation')),
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
              onPressed: _signing
                  ? null
                  : () => _sign(provider.definition, fields),
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
