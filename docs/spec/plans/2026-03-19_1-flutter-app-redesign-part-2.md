# Flutter App Redesign — Implementation Plan (Part 2)

> Continues from [Part 1](2026-03-19_1-flutter-app-redesign.md). Tasks 18–32.

---

## Part 2: Screens & Features

### Sub-Phase C: Widget Rewrites + Screen Rewrites (Offchain)

---

### Task 18: Create `AttestationResultCard` widget

**Files:**
- Create: `lib/widgets/attestation_result_card.dart`

- [ ] **Step 1: Write the widget**

This is a reusable display widget for showing `SignedOffchainAttestation` results. Since it's purely presentational, we don't TDD the widget itself — we verify it compiles and integrates during screen tests.

```dart
// lib/widgets/attestation_result_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location_protocol/location_protocol.dart';

/// Displays the result of a signed offchain attestation.
class AttestationResultCard extends StatelessWidget {
  final SignedOffchainAttestation attestation;

  const AttestationResultCard({super.key, required this.attestation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attestation Signed', style: theme.textTheme.titleLarge),
            const Divider(),
            _row('UID', attestation.uid),
            _row('Signer', attestation.signer),
            _row('Schema UID', attestation.schemaUID),
            _row('Time', DateTime.fromMillisecondsSinceEpoch(
              attestation.time.toInt() * 1000,
            ).toIso8601String()),
            _row('Version', attestation.version.toString()),
            _row('Salt', attestation.salt),
            const Divider(),
            Text('Signature', style: theme.textTheme.titleSmall),
            _row('v', attestation.signature.v.toString()),
            _row('r', attestation.signature.r),
            _row('s', attestation.signature.s),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _copyToClipboard(context),
                icon: const Icon(Icons.copy),
                label: const Text('Copy Full Result'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _copyToClipboard(BuildContext context) {
    final text = '''UID: ${attestation.uid}
Signer: ${attestation.signer}
Schema UID: ${attestation.schemaUID}
Time: ${attestation.time}
Version: ${attestation.version}
Salt: ${attestation.salt}
Signature v: ${attestation.signature.v}
Signature r: ${attestation.signature.r}
Signature s: ${attestation.signature.s}''';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/attestation_result_card.dart
git commit -m "feat: add AttestationResultCard widget for signed attestation display"
```

---

### Task 19: Create `ChainSelector` widget

**Files:**
- Create: `lib/widgets/chain_selector.dart`

- [ ] **Step 1: Write the widget**

```dart
// lib/widgets/chain_selector.dart
import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';

/// Dropdown widget for selecting a target chain from supported chains.
class ChainSelector extends StatelessWidget {
  final int selectedChainId;
  final ValueChanged<int> onChanged;

  const ChainSelector({
    super.key,
    required this.selectedChainId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chainIds = ChainConfig.supportedChainIds;

    return DropdownButtonFormField<int>(
      value: selectedChainId,
      decoration: const InputDecoration(
        labelText: 'Target Chain',
        border: OutlineInputBorder(),
      ),
      items: chainIds.map((id) {
        final config = ChainConfig.forChainId(id)!;
        return DropdownMenuItem(
          value: id,
          child: Text('${config.chainName} ($id)'),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/chain_selector.dart
git commit -m "feat: add ChainSelector dropdown widget"
```

---

### Task 20: Rewrite `PrivateKeyImportDialog`

**Files:**
- Create: `lib/widgets/private_key_import_dialog.dart`

- [ ] **Step 1: Write the new dialog**

```dart
// lib/widgets/private_key_import_dialog.dart
import 'package:flutter/material.dart';

/// Shows a bottom-sheet dialog for importing a hex private key.
///
/// Returns the 64-character hex private key (without 0x prefix) or null if cancelled.
Future<String?> showPrivateKeyImportDialog(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _PrivateKeyImportSheet(),
  );
}

class _PrivateKeyImportSheet extends StatefulWidget {
  const _PrivateKeyImportSheet();

  @override
  State<_PrivateKeyImportSheet> createState() => _PrivateKeyImportSheetState();
}

class _PrivateKeyImportSheetState extends State<_PrivateKeyImportSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    // Clear the key from memory.
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    var key = _controller.text.trim();
    if (key.startsWith('0x')) key = key.substring(2);

    if (key.length != 64 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(key)) {
      setState(() => _error = 'Enter a valid 64-character hex private key');
      return;
    }

    // Return the key and immediately clear the controller.
    final result = key;
    _controller.clear();
    Navigator.of(context).pop(result);
    // Note: The caller MUST NOT persist this key to disk or logs.
    // See PRD Non-Functional Requirements: Security.
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Import Private Key',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter a 64-character hex private key. This key will NOT be stored.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Private Key (hex)',
              hintText: 'ac0974bec39a17e36ba4a6b4d238ff944bacb478...',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            obscureText: true,
            maxLength: 66, // 64 hex + optional 0x prefix
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                child: const Text('Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/private_key_import_dialog.dart
git commit -m "feat: rewrite PrivateKeyImportDialog targeting library types"
```

---

### Task 21: Rewrite `ExternalSignDialog`

**Files:**
- Create: `lib/widgets/external_sign_dialog.dart`

- [ ] **Step 1: Write the new dialog**

```dart
// lib/widgets/external_sign_dialog.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location_protocol/location_protocol.dart';

/// Shows a bottom-sheet dialog for external wallet signing.
///
/// Displays the typed data JSON for the user to copy and sign externally,
/// then accepts the pasted 65-byte hex signature.
///
/// Returns an [EIP712Signature] or null if cancelled.
Future<EIP712Signature?> showExternalSignDialog(
  BuildContext context,
  Map<String, dynamic> typedData,
) {
  return showModalBottomSheet<EIP712Signature>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ExternalSignSheet(typedData: typedData),
  );
}

class _ExternalSignSheet extends StatefulWidget {
  final Map<String, dynamic> typedData;

  const _ExternalSignSheet({required this.typedData});

  @override
  State<_ExternalSignSheet> createState() => _ExternalSignSheetState();
}

class _ExternalSignSheetState extends State<_ExternalSignSheet> {
  final _sigController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  void _copyTypedData() {
    final json = const JsonEncoder.withIndent('  ').convert(widget.typedData);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Typed data copied to clipboard')),
    );
  }

  void _submit() {
    final sigHex = _sigController.text.trim();

    try {
      final sig = EIP712Signature.fromHex(sigHex);
      Navigator.of(context).pop(sig);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(widget.typedData);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'Sign with External Wallet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Copy the typed data below\n'
                '2. Sign it with your wallet (e.g., MetaMask → eth_signTypedData_v4)\n'
                '3. Paste the 65-byte hex signature',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('EIP-712 Typed Data',
                      style: Theme.of(context).textTheme.titleSmall),
                  IconButton(
                    onPressed: _copyTypedData,
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy typed data',
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  jsonStr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sigController,
                decoration: InputDecoration(
                  labelText: 'Signature (65-byte hex)',
                  hintText: '0x...',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                maxLines: 2,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Submit Signature'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/external_sign_dialog.dart
git commit -m "feat: rewrite ExternalSignDialog for library EIP712Signature type"
```

---

### Task 22: Rewrite `SignScreen`

**Files:**
- Create: `lib/screens/sign_screen.dart` (overwrite existing)

- [ ] **Step 1: Write the new SignScreen**

```dart
// lib/screens/sign_screen.dart
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
                  child: Text(_error!,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer)),
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/sign_screen.dart
git commit -m "feat: rewrite SignScreen using AttestationService and library types"
```

---

### Task 23: Rewrite `VerifyScreen` — with JSON deserialization

**Files:**
- Create: `lib/screens/verify_screen.dart` (overwrite existing)

- [ ] **Step 1: Write the new VerifyScreen**

The key challenge here is deserializing pasted JSON into `SignedOffchainAttestation`. The library does not provide `fromJson()`, so we handle parsing here.

```dart
// lib/screens/verify_screen.dart
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
                  child: Text(_error!,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer)),
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
            if (_result!.reason != null)
              _infoRow('Reason', _result!.reason!),
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
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
```

- [ ] **Step 2: Write JSON parsing test**

```dart
// test/screens/verify_screen_parsing_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

void main() {
  group('Verify JSON round-trip', () {
    test('sign → serialize → deserialize → verify', () async {
      final service = AttestationService(
        signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
        chainId: 11155111,
      );

      // Sign
      final signed = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'json round trip',
      );

      // Serialize to JSON (manual since library doesn't provide toJson)
      final jsonMap = {
        'uid': signed.uid,
        'schemaUID': signed.schemaUID,
        'recipient': signed.recipient,
        'time': signed.time.toInt(),
        'expirationTime': signed.expirationTime.toInt(),
        'revocable': signed.revocable,
        'refUID': signed.refUID,
        'data': '0x${signed.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
        'salt': signed.salt,
        'version': signed.version,
        'signature': {
          'v': signed.signature.v,
          'r': signed.signature.r,
          's': signed.signature.s,
        },
        'signer': signed.signer,
      };
      final jsonText = jsonEncode(jsonMap);

      // Deserialize
      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
      final dataHex = parsed['data'] as String;
      final dataClean = dataHex.startsWith('0x') ? dataHex.substring(2) : dataHex;
      final data = Uint8List.fromList([
        for (var i = 0; i < dataClean.length; i += 2)
          int.parse(dataClean.substring(i, i + 2), radix: 16),
      ]);
      final sigMap = parsed['signature'] as Map<String, dynamic>;
      final restored = SignedOffchainAttestation(
        uid: parsed['uid'] as String,
        schemaUID: parsed['schemaUID'] as String,
        recipient: parsed['recipient'] as String,
        time: BigInt.from(parsed['time'] as int),
        expirationTime: BigInt.from(parsed['expirationTime'] as int),
        revocable: parsed['revocable'] as bool,
        refUID: parsed['refUID'] as String,
        data: data,
        salt: parsed['salt'] as String,
        version: parsed['version'] as int,
        signature: EIP712Signature(
          v: sigMap['v'] as int,
          r: sigMap['r'] as String,
          s: sigMap['s'] as String,
        ),
        signer: parsed['signer'] as String,
      );

      // Verify
      final result = service.verifyOffchain(restored);
      expect(result.isValid, isTrue);
    });
  });
}
```

- [ ] **Step 3: Run test**

Run: `flutter test test/screens/verify_screen_parsing_test.dart -v`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/screens/verify_screen.dart test/screens/verify_screen_parsing_test.dart
git commit -m "feat: rewrite VerifyScreen with JSON parsing for SignedOffchainAttestation"
```

---

### Task 24: Rewrite `HomeScreen`

**Files:**
- Create: `lib/screens/home_screen.dart` (overwrite existing)

- [ ] **Step 1: Write the new HomeScreen**

```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';

import '../privy/privy_module.dart';
import '../protocol/protocol_module.dart';
import '../widgets/private_key_import_dialog.dart';
import '../widgets/external_sign_dialog.dart';
import 'sign_screen.dart';
import 'verify_screen.dart';
import 'onchain_attest_screen.dart';
import 'register_schema_screen.dart';
import 'timestamp_screen.dart';
import '../settings/settings_screen.dart';

/// Main screen — auth-gated navigation hub for all attestation operations.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = PrivyAuthProvider.of(context);

    if (!auth.isReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Location Protocol')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Protocol'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          if (auth.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => auth.logout(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (auth.isAuthenticated && auth.walletAddress != null) ...[
              _WalletCard(address: auth.walletAddress!),
              const SizedBox(height: 16),
            ],

            if (!auth.isAuthenticated) ...[
              _buildLoginButton(context),
              const SizedBox(height: 12),
            ],

            // --- Always available ---
            _SectionHeader('Offchain Operations'),
            _buildPrivateKeySignButton(context),
            const SizedBox(height: 8),
            _buildVerifyButton(context),
            const SizedBox(height: 8),

            // --- Auth-gated ---
            if (auth.isAuthenticated) ...[
              _buildSignWithWalletButton(context, auth),
              const SizedBox(height: 8),
              _buildExternalWalletSignButton(context, auth),
              const SizedBox(height: 24),

              _SectionHeader('Onchain Operations'),
              _buildOnchainAttestButton(context, auth),
              const SizedBox(height: 8),
              _buildRegisterSchemaButton(context, auth),
              const SizedBox(height: 8),
              _buildTimestampButton(context, auth),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => showPrivyLoginModal(context),
      icon: const Icon(Icons.login),
      label: const Text('Login with Privy'),
    );
  }

  Widget _buildSignWithWalletButton(BuildContext context, PrivyAuthState auth) {
    return _ActionButton(
      icon: Icons.edit_note,
      label: 'Sign with Embedded Wallet',
      onPressed: () {
        if (auth.wallet == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No embedded wallet available')),
          );
          return;
        }
        final signer = PrivySigner.fromWallet(auth.wallet!);
        final service = AttestationService(signer: signer, chainId: 11155111);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SignScreen(service: service)),
        );
      },
    );
  }

  Widget _buildExternalWalletSignButton(
      BuildContext context, PrivyAuthState auth) {
    return _ActionButton(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Sign with External Wallet',
      onPressed: () {
        if (auth.walletAddress == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No wallet address available')),
          );
          return;
        }
        final signer = ExternalWalletSigner(
          walletAddress: auth.walletAddress!,
          onSignTypedData: (typedData) async {
            final sig = await showExternalSignDialog(context, typedData);
            if (sig == null) throw Exception('Signing cancelled');
            return sig;
          },
        );
        final service = AttestationService(signer: signer, chainId: 11155111);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SignScreen(service: service)),
        );
      },
    );
  }

  Widget _buildPrivateKeySignButton(BuildContext context) {
    return _ActionButton(
      icon: Icons.key,
      label: 'Sign with Private Key',
      onPressed: () async {
        final key = await showPrivateKeyImportDialog(context);
        if (key == null || !context.mounted) return;
        final signer = LocalKeySigner(privateKeyHex: key);
        final service = AttestationService(signer: signer, chainId: 11155111);
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SignScreen(service: service)),
          );
        }
      },
    );
  }

  Widget _buildVerifyButton(BuildContext context) {
    // Create a dummy service for verification (signer not used for verify)
    return _ActionButton(
      icon: Icons.verified,
      label: 'Verify Attestation',
      onPressed: () {
        // For verify, we need a service but the signer doesn't matter.
        // Use a throwaway LocalKeySigner — verify doesn't sign anything.
        final dummySigner = LocalKeySigner(
          privateKeyHex:
              'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
        );
        final service =
            AttestationService(signer: dummySigner, chainId: 11155111);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VerifyScreen(service: service)),
        );
      },
    );
  }

  Widget _buildOnchainAttestButton(BuildContext context, PrivyAuthState auth) {
    return _ActionButton(
      icon: Icons.cloud_upload,
      label: 'Attest Onchain',
      onPressed: () {
        if (auth.wallet == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Onchain operations require an embedded wallet')),
          );
          return;
        }
        final signer = PrivySigner.fromWallet(auth.wallet!);
        final service = AttestationService(signer: signer, chainId: 11155111);
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => OnchainAttestScreen(
                    service: service,
                    wallet: auth.wallet!,
                  )),
        );
      },
    );
  }

  Widget _buildRegisterSchemaButton(
      BuildContext context, PrivyAuthState auth) {
    return _ActionButton(
      icon: Icons.app_registration,
      label: 'Register Schema',
      onPressed: () {
        if (auth.wallet == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Schema registration requires an embedded wallet')),
          );
          return;
        }
        final signer = PrivySigner.fromWallet(auth.wallet!);
        final service = AttestationService(signer: signer, chainId: 11155111);
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => RegisterSchemaScreen(
                    service: service,
                    wallet: auth.wallet!,
                  )),
        );
      },
    );
  }

  Widget _buildTimestampButton(BuildContext context, PrivyAuthState auth) {
    return _ActionButton(
      icon: Icons.access_time,
      label: 'Timestamp Offchain UID',
      onPressed: () {
        if (auth.wallet == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Timestamping requires an embedded wallet')),
          );
          return;
        }
        final signer = PrivySigner.fromWallet(auth.wallet!);
        final service = AttestationService(signer: signer, chainId: 11155111);
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => TimestampScreen(
                    service: service,
                    wallet: auth.wallet!,
                  )),
        );
      },
    );
  }
}

class _WalletCard extends StatelessWidget {
  final String address;
  const _WalletCard({required this.address});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connected Wallet',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SelectableText(
                    address,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: rewrite HomeScreen with expanded nav for all attestation operations"
```

---

### Task 25: Update widget smoke test

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Update the smoke test**

```dart
// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/screens/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('HomeScreen without PrivyAuthProvider throws FlutterError', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );

    // HomeScreen calls PrivyAuthProvider.of(context), which throws if
    // there's no ancestor PrivyAuthProvider.
    expect(tester.takeException(), isA<FlutterError>());
  });
}
```

- [ ] **Step 2: Run test**

Run: `flutter test test/widget_test.dart -v`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: update widget smoke test for rewritten HomeScreen"
```

---

### Sub-Phase D: New Screens (Onchain) + Settings

---

### Task 26: Create `SettingsService`

**Files:**
- Create: `lib/settings/settings_service.dart`
- Create: `test/settings/settings_service_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/settings/settings_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location_protocol_flutter_app/settings/settings_service.dart';

void main() {
  group('SettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('rpcUrl defaults to empty string', () async {
      final service = await SettingsService.create();
      expect(service.rpcUrl, '');
    });

    test('saves and retrieves rpcUrl', () async {
      final service = await SettingsService.create();
      await service.setRpcUrl('https://rpc.example.com');
      expect(service.rpcUrl, 'https://rpc.example.com');
    });

    test('selectedChainId defaults to 11155111 (Sepolia)', () async {
      final service = await SettingsService.create();
      expect(service.selectedChainId, 11155111);
    });

    test('saves and retrieves selectedChainId', () async {
      final service = await SettingsService.create();
      await service.setSelectedChainId(1);
      expect(service.selectedChainId, 1);
    });

    test('privateKeyHex defaults to empty string', () async {
      final service = await SettingsService.create();
      expect(service.privateKeyHex, '');
    });

    test('saves and retrieves privateKeyHex', () async {
      final service = await SettingsService.create();
      await service.setPrivateKeyHex('abcd1234');
      expect(service.privateKeyHex, 'abcd1234');
    });

    test('clearPrivateKey removes the stored key', () async {
      final service = await SettingsService.create();
      await service.setPrivateKeyHex('secret');
      await service.clearPrivateKey();
      expect(service.privateKeyHex, '');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/settings/settings_service_test.dart -v`
Expected: FAIL — file does not exist

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/settings/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Persists dev/test settings via SharedPreferences.
///
/// Stores RPC URL, chain ID, and (optionally) a private key for
/// the dev/test private-key path. The private key is stored in
/// SharedPreferences which is NOT secure storage — this is acceptable
/// for a dev/test tool, not for production key management.
class SettingsService {
  static const _keyRpcUrl = 'settings_rpc_url';
  static const _keyChainId = 'settings_chain_id';
  static const _keyPrivateKey = 'settings_private_key';

  final SharedPreferences _prefs;

  SettingsService._(this._prefs);

  /// Creates a [SettingsService] backed by SharedPreferences.
  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService._(prefs);
  }

  String get rpcUrl => _prefs.getString(_keyRpcUrl) ?? '';

  Future<void> setRpcUrl(String url) => _prefs.setString(_keyRpcUrl, url);

  int get selectedChainId => _prefs.getInt(_keyChainId) ?? 11155111;

  Future<void> setSelectedChainId(int chainId) =>
      _prefs.setInt(_keyChainId, chainId);

  String get privateKeyHex => _prefs.getString(_keyPrivateKey) ?? '';

  Future<void> setPrivateKeyHex(String key) =>
      _prefs.setString(_keyPrivateKey, key);

  Future<void> clearPrivateKey() => _prefs.remove(_keyPrivateKey);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/settings/settings_service_test.dart -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/settings/settings_service.dart test/settings/settings_service_test.dart
git commit -m "feat: add SettingsService with SharedPreferences for dev/test config"
```

---

### Task 27: Create `SettingsScreen`

**Files:**
- Create: `lib/settings/settings_screen.dart`

- [ ] **Step 1: Write the settings screen**

```dart
// lib/settings/settings_screen.dart
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
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
                  Text('Developer / Test Configuration',
                      style: Theme.of(context).textTheme.titleMedium),
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/settings/settings_screen.dart
git commit -m "feat: add SettingsScreen for dev/test RPC, chain, and private key config"
```

---

### Task 28: Create `OnchainAttestScreen`

**Files:**
- Create: `lib/screens/onchain_attest_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
// lib/screens/onchain_attest_screen.dart
import 'package:flutter/material.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:location_protocol/location_protocol.dart';

import '../protocol/attestation_service.dart';
import '../widgets/chain_selector.dart';

/// Screen for creating an onchain attestation via the Privy wallet.
///
/// Uses the static builder pipeline:
/// EASClient.buildAttestCallData → TxUtils.buildTxRequest → eth_sendTransaction
class OnchainAttestScreen extends StatefulWidget {
  final AttestationService service;
  final EmbeddedEthereumWallet wallet;

  const OnchainAttestScreen({
    super.key,
    required this.service,
    required this.wallet,
  });

  @override
  State<OnchainAttestScreen> createState() => _OnchainAttestScreenState();
}

class _OnchainAttestScreenState extends State<OnchainAttestScreen> {
  final _latController = TextEditingController(text: '37.7749');
  final _lngController = TextEditingController(text: '-122.4194');
  final _memoController = TextEditingController();

  bool _submitting = false;
  String? _txHash;
  String? _error;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _txHash = null;
      _error = null;
    });

    try {
      final lat = double.parse(_latController.text.trim());
      final lng = double.parse(_lngController.text.trim());
      final memo = _memoController.text.trim();

      // Build calldata
      final callData = widget.service.buildAttestCallData(
        lat: lat,
        lng: lng,
        memo: memo.isEmpty ? 'No memo' : memo,
      );

      // Build tx request
      final txRequest = widget.service.buildTxRequest(
        callData: callData,
        contractAddress: widget.service.easAddress,
      );

      // Send via Privy wallet
      final result = await widget.wallet.provider.request(
        EthereumRpcRequest(
          method: 'eth_sendTransaction',
          params: [txRequest],
        ),
      );

      late String txHash;
      result.fold(
        onSuccess: (r) => txHash = r.data,
        onFailure: (e) => throw Exception('Transaction failed: ${e.message}'),
      );

      if (mounted) setState(() => _txHash = txHash);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _explorerUrl(String txHash) {
    // Default to Sepolia Etherscan
    return 'https://sepolia.etherscan.io/tx/$txHash';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onchain Attestation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create an onchain attestation. This submits a transaction '
              'and requires gas.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
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
              onPressed: _submitting ? null : _submit,
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
                  child: Text(_error!,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer)),
                ),
              ),
            ],
            if (_txHash != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Transaction Submitted',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      SelectableText(
                        'TX Hash: $_txHash',
                        style:
                            const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          // In a real app, launch URL. For now, copy.
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'View at: ${_explorerUrl(_txHash!)}')),
                          );
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('View on Block Explorer'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/onchain_attest_screen.dart
git commit -m "feat: add OnchainAttestScreen with static builder pipeline"
```

---

### Task 29: Create `RegisterSchemaScreen`

**Files:**
- Create: `lib/screens/register_schema_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
// lib/screens/register_schema_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:privy_flutter/privy_flutter.dart';

import '../protocol/attestation_service.dart';
import '../protocol/schema_config.dart';

/// Screen for registering the app's EAS schema onchain.
class RegisterSchemaScreen extends StatefulWidget {
  final AttestationService service;
  final EmbeddedEthereumWallet wallet;

  const RegisterSchemaScreen({
    super.key,
    required this.service,
    required this.wallet,
  });

  @override
  State<RegisterSchemaScreen> createState() => _RegisterSchemaScreenState();
}

class _RegisterSchemaScreenState extends State<RegisterSchemaScreen> {
  bool _submitting = false;
  String? _txHash;
  String? _error;

  Future<void> _register() async {
    setState(() {
      _submitting = true;
      _txHash = null;
      _error = null;
    });

    try {
      final callData = widget.service.buildRegisterSchemaCallData();
      final txRequest = widget.service.buildTxRequest(
        callData: callData,
        contractAddress: widget.service.schemaRegistryAddress,
      );

      final result = await widget.wallet.provider.request(
        EthereumRpcRequest(
          method: 'eth_sendTransaction',
          params: [txRequest],
        ),
      );

      late String txHash;
      result.fold(
        onSuccess: (r) => txHash = r.data,
        onFailure: (e) => throw Exception('Transaction failed: ${e.message}'),
      );

      if (mounted) setState(() => _txHash = txHash);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schemaString = AppSchema.definition.toEASSchemaString();

    return Scaffold(
      appBar: AppBar(title: const Text('Register Schema')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Schema String', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                schemaString,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Schema UID', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: AppSchema.schemaUID));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Schema UID copied')),
                    );
                  },
                ),
              ],
            ),
            SelectableText(
              AppSchema.schemaUID,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _register,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Register Schema Onchain'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!),
                ),
              ),
            ],
            if (_txHash != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Schema Registration Submitted',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SelectableText('TX Hash: $_txHash',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/register_schema_screen.dart
git commit -m "feat: add RegisterSchemaScreen with static builder pipeline"
```

---

### Task 30: Create `TimestampScreen`

**Files:**
- Create: `lib/screens/timestamp_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
// lib/screens/timestamp_screen.dart
import 'package:flutter/material.dart';
import 'package:privy_flutter/privy_flutter.dart';

import '../protocol/attestation_service.dart';

/// Screen for timestamping an offchain attestation UID onchain.
class TimestampScreen extends StatefulWidget {
  final AttestationService service;
  final EmbeddedEthereumWallet wallet;

  const TimestampScreen({
    super.key,
    required this.service,
    required this.wallet,
  });

  @override
  State<TimestampScreen> createState() => _TimestampScreenState();
}

class _TimestampScreenState extends State<TimestampScreen> {
  final _uidController = TextEditingController();
  bool _submitting = false;
  String? _txHash;
  String? _error;

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = _uidController.text.trim();
    if (!uid.startsWith('0x') || uid.length != 66) {
      setState(() => _error = 'Enter a valid 0x-prefixed 32-byte hex UID');
      return;
    }

    setState(() {
      _submitting = true;
      _txHash = null;
      _error = null;
    });

    try {
      final callData = widget.service.buildTimestampCallData(uid);
      final txRequest = widget.service.buildTxRequest(
        callData: callData,
        contractAddress: widget.service.easAddress,
      );

      final result = await widget.wallet.provider.request(
        EthereumRpcRequest(
          method: 'eth_sendTransaction',
          params: [txRequest],
        ),
      );

      late String txHash;
      result.fold(
        onSuccess: (r) => txHash = r.data,
        onFailure: (e) => throw Exception('Transaction failed: ${e.message}'),
      );

      if (mounted) setState(() => _txHash = txHash);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Timestamp Offchain UID')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Anchor an offchain attestation UID onchain for immutable '
              'proof of existence.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _uidController,
              decoration: const InputDecoration(
                labelText: 'Offchain UID (0x-prefixed hex)',
                hintText: '0x...',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Timestamp Onchain'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!),
                ),
              ),
            ],
            if (_txHash != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Timestamp Submitted',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SelectableText('TX Hash: $_txHash',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/timestamp_screen.dart
git commit -m "feat: add TimestampScreen for onchain UID anchoring"
```

---

### Task 31: Rewire `main.dart`

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Update main.dart**

Replace the current contents of `lib/main.dart`:

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'privy/privy_module.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const LocationProtocolApp());
}

class LocationProtocolApp extends StatelessWidget {
  const LocationProtocolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return PrivyAuthProvider(
      config: PrivyAuthConfig(
        appId: dotenv.env['PRIVY_APP_ID'] ?? '',
        clientId: dotenv.env['PRIVY_CLIENT_ID'] ?? '',
        oauthAppUrlScheme: dotenv.env['PRIVY_OAUTH_APP_URL_SCHEME'],
        loginMethods: const [
          LoginMethod.sms,
          LoginMethod.email,
          LoginMethod.google,
          LoginMethod.twitter,
          LoginMethod.discord,
          LoginMethod.siwe,
        ],
        autoCreateWallet: true,
      ),
      child: MaterialApp(
        title: 'Location Protocol Signature Service',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
```

Note: `LocationProtocolProvider` is removed — `AttestationService` is now created per-operation in `HomeScreen` with the appropriate signer.

- [ ] **Step 2: Run `flutter analyze`**

Run: `flutter analyze`
Expected: Zero new issues

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "refactor: rewire main.dart — remove LocationProtocolProvider, use Privy + AttestationService"
```

---

### Task 32: Part 2 checkpoint — `flutter analyze`

**Files:** None (verification only)

- [ ] **Step 1: Run `flutter analyze`**

Run: `flutter analyze`
Expected: Zero issues (may have warnings from old code still present — that's OK, it gets deleted in Part 3)

- [ ] **Step 2: Run new tests**

Run: `flutter test test/protocol/ test/settings/ test/screens/ test/privy/ test/widget_test.dart`
Expected: ALL PASS

- [ ] **Step 3: Commit**

```bash
git commit -am "chore: Part 2 checkpoint — screens, widgets, settings complete"
```

---

Continue to [Part 3: Cleanup & Verification](2026-03-19_1-flutter-app-redesign-part-3.md).
