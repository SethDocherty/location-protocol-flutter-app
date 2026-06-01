import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:provider/provider.dart';

import '../protocol/attestation_service.dart';
import '../protocol/eas_scan_service.dart';
import '../providers/app_wallet_provider.dart';
import '../providers/schema_provider.dart';
import '../utils/network_links.dart';

class SchemaManagerScreen extends StatefulWidget {
  final AttestationService? service;

  const SchemaManagerScreen({super.key, this.service});

  @override
  State<SchemaManagerScreen> createState() => _SchemaManagerScreenState();
}

class _SchemaManagerScreenState extends State<SchemaManagerScreen> {
  bool _checking = false;
  bool _isRegistered = false;
  bool _submitting = false;
  bool _loadingSchemas = false;
  String? _txHash;
  String? _error;
  List<RegisteredSchema> _userSchemas = [];
  String? _lastCheckedUID;

  static const _lpBaseFieldNames = {'lp_version', 'srs', 'location_type', 'location'};

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
    _fetchUserSchemas();
  }

  Future<void> _checkRegistrationStatus() async {
    final service = widget.service;
    if (service == null) return;

    final provider = context.read<SchemaProvider>();
    final uid = provider.schemaUID;
    _lastCheckedUID = uid;

    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final exists = await service.isSchemaUidRegistered(uid);
      if (mounted) setState(() => _isRegistered = exists);
    } catch (e) {
      if (mounted) setState(() => _error = 'Status check failed: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _fetchUserSchemas() async {
    final wallet = context.read<AppWalletProvider>();
    final address = wallet.walletAddress;
    final chainId = widget.service?.chainId;

    if (address == null || chainId == null) return;

    final domain = NetworkLinks.getEasScanDomain(chainId);
    if (domain == null) return;

    setState(() => _loadingSchemas = true);

    try {
      final easService = EasScanService(graphqlEndpoint: '$domain/graphql');
      final schemas = await easService.queryUserSchemas(address);
      if (mounted) setState(() => _userSchemas = schemas);
    } catch (e) {
      debugPrint('Error fetching user schemas: $e');
    } finally {
      if (mounted) setState(() => _loadingSchemas = false);
    }
  }

  List<SchemaField> _parseSchemaString(String schemaString) {
    return schemaString
        .split(',')
        .map((part) => part.trim().split(' '))
        .where((parts) => parts.length == 2)
        .map((parts) => SchemaField(type: parts[0], name: parts[1]))
        .where((f) => !_lpBaseFieldNames.contains(f.name))
        .toList();
  }

  Future<void> _register() async {
    final service = widget.service;
    if (service == null) return;

    setState(() {
      _submitting = true;
      _txHash = null;
      _error = null;
    });

    try {
      final provider = context.read<SchemaProvider>();
      final callData = service.buildRegisterSchemaCallData(provider.definition);
      final txRequest = service.buildTxRequest(
        callData: callData,
        contractAddress: service.schemaRegistryAddress,
      );

      final txHash = await context.read<AppWalletProvider>().sendTransaction(
            txRequest,
            context: context,
          );

      if (txHash == null) throw Exception('Transaction cancelled');
      if (mounted) setState(() => _txHash = txHash);
      
      // Verification will refresh status automatically on re-check
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SchemaProvider>();
    final fields = provider.userFields;

    // Trigger registration re-check if UID changed
    if (_lastCheckedUID != provider.schemaUID && !_checking) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkRegistrationStatus());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schema Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _checkRegistrationStatus();
              _fetchUserSchemas();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusHeader(provider.schemaUID),
            const SizedBox(height: 24),
            _buildEasScanSection(provider),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('User Fields', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: provider.resetToDefault,
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...fields.map((f) => _buildFieldTile(f, provider)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showAddFieldDialog(provider),
              icon: const Icon(Icons.add),
              label: const Text('Add Field'),
            ),
            const SizedBox(height: 32),
            _buildRegisterSection(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(String uid) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active Schema UID', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      SelectableText(uid, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: uid));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UID copied')));
                  },
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _checking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_isRegistered ? Icons.check_circle : Icons.warning, color: _isRegistered ? Colors.green : Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  _isRegistered ? 'Registered Onchain' : 'Not Registered Onchain',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isRegistered ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEasScanSection(SchemaProvider provider) {
    // Show a slim loading bar independently while fetching, without
    // rendering an empty dropdown that flashes and then disappears.
    if (_userSchemas.isEmpty) {
      if (!_loadingSchemas) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: LinearProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Import from EAS Scan', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<RegisteredSchema>(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            hintText: 'Select a previously registered schema',
          ),
          items: _userSchemas.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Text('Schema #${s.index} (${s.id.substring(0, 10)}...)'),
            );
          }).toList(),
          onChanged: (schema) {
            if (schema != null) {
              provider.setSchema(_parseSchemaString(schema.schema));
            }
          },
        ),
      ],
    );
  }

  Widget _buildFieldTile(SchemaField field, SchemaProvider provider) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(field.name),
        subtitle: Text(field.type, style: const TextStyle(fontFamily: 'monospace')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => provider.removeField(field.name),
        ),
      ),
    );
  }

  Widget _buildRegisterSection(SchemaProvider provider) {
    if (widget.service == null) {
      return const Center(child: Text('Connect a wallet to register schemas.'));
    }

    return Column(
      children: [
        FilledButton.icon(
          onPressed: (_isRegistered || _submitting || _checking) ? null : _register,
          icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload),
          label: Text(_isRegistered ? 'Already Registered' : 'Register Onchain'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_txHash != null) ...[
          const SizedBox(height: 16),
          Text('Transaction submitted: $_txHash', style: const TextStyle(fontSize: 12)),
        ],
      ],
    );
  }

  void _showAddFieldDialog(SchemaProvider provider) {
    String type = 'string';
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Schema Field'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      'string', 'uint256', 'address', 'bool', 'bytes', 'bytes32', 'string[]', 'bytes[]'
                    ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setDialogState(() => type = v!),
                    decoration: const InputDecoration(labelText: 'Type'),
                  ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    provider.addField(SchemaField(type: type, name: nameController.text));
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
