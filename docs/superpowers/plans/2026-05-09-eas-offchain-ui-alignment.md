# EAS Offchain UI Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the app’s legacy flat offchain attestation JSON flow with canonical EAS envelope import/export, while keeping the existing sign and verify UX mostly intact.

**Architecture:** Treat `SignedOffchainAttestation` from `location_protocol` as the single source of truth and route all app import/export through its canonical `toJson()` / `fromJson()` APIs. Add a thin app-local JSON-safe normalization layer for stable clipboard output, then update the verify screen and result card to consume that canonical shape without reintroducing a second flattened model.

**Tech Stack:** Flutter, Dart, `location_protocol`, `flutter_test`, Material UI

---

### Task 1: Replace the legacy JSON adapter with a canonical EAS envelope adapter

**Files:**
- Modify: `lib/utils/attestation_json.dart`
- Modify: `test/screens/verify_screen_parsing_test.dart`
- Modify: `test/protocol/round_trip_test.dart`

- [ ] **Step 1: Write the failing tests for canonical export and import**

Add the following assertions to `test/screens/verify_screen_parsing_test.dart` so the adapter is forced to export the canonical EAS shape and preserve numeric message fields as JSON numbers:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/utils/attestation_json.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

void main() {
  group('Verify JSON round-trip', () {
    test('sign → serialize → deserialize → verify', () async {
      final service = AttestationService(
        signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
        chainId: 11155111,
        rpcUrl: 'https://unused.rpc',
      );

      final signed = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'json round trip',
      );

      final jsonText = encodeSignedOffchainAttestationJson(signed);
      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
      final sig = parsed['sig'] as Map<String, dynamic>;
      final message = sig['message'] as Map<String, dynamic>;

      expect(parsed['signer'], signed.signer);
      expect(sig['uid'], signed.uid);
      expect(sig['primaryType'], 'Attest');
      expect(sig['domain'], isA<Map<String, dynamic>>());
      expect(sig['types'], isA<Map<String, dynamic>>());
      expect(message['schema'], signed.schemaUID);
      expect(message['time'], isA<int>());
      expect(message['expirationTime'], isA<int>());
      expect(message['version'], isA<int>());

      final restored = decodeSignedOffchainAttestationJson(jsonText);
      final result = service.verifyOffchain(restored);
      expect(result.isValid, isTrue);
    });

    test('decode rejects non-canonical JSON', () {
      expect(
        () => decodeSignedOffchainAttestationJson(
          '{"uid":"0x1234","schemaUID":"0x5678"}',
        ),
        throwsFormatException,
      );
    });
  });
}
```

Update `test/protocol/round_trip_test.dart` so the old `version` and `salt` expectations are replaced by the new derived getters and a JSON serialization check:

```dart
test('attestation exports canonical version 2 envelope', () async {
  final signed = await service.signOffchain(
    lat: 0,
    lng: 0,
    memo: 'version test',
  );

  expect(signed.offchainVersion, 2);
  expect(signed.saltHex, isNotNull);

  final json = signedOffchainAttestationToJsonMap(signed);
  final sig = json['sig'] as Map<String, dynamic>;
  final message = sig['message'] as Map<String, dynamic>;

  expect(sig['uid'], signed.uid);
  expect(message['version'], 2);
  expect(message['salt'], signed.saltHex);
});
```

- [ ] **Step 2: Run the targeted tests to verify they fail first**

Run: `flutter test test/screens/verify_screen_parsing_test.dart test/protocol/round_trip_test.dart`

Expected: FAIL with errors around missing canonical `sig` fields and/or references to obsolete flat-model getters like `version` and `salt`.

- [ ] **Step 3: Implement the canonical adapter in `lib/utils/attestation_json.dart`**

Replace the current flattened serializer/deserializer with a thin wrapper around upstream `SignedOffchainAttestation.toJson()` / `SignedOffchainAttestation.fromJson()` and a recursive JSON-safe normalizer modeled on the upstream script:

```dart
import 'dart:convert';

import 'package:location_protocol/location_protocol.dart';

Map<String, dynamic> signedOffchainAttestationToJsonMap(
  SignedOffchainAttestation attestation,
) {
  final canonical = attestation.toJson();
  return Map<String, dynamic>.from(_jsonSafeValue(canonical) as Map);
}

String encodeSignedOffchainAttestationJson(
  SignedOffchainAttestation attestation, {
  bool pretty = true,
}) {
  final map = signedOffchainAttestationToJsonMap(attestation);
  if (pretty) {
    return const JsonEncoder.withIndent('  ').convert(map);
  }
  return jsonEncode(map);
}

SignedOffchainAttestation decodeSignedOffchainAttestationJson(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON object.',
    );
  }
  return signedOffchainAttestationFromJsonMap(decoded);
}

SignedOffchainAttestation signedOffchainAttestationFromJsonMap(
  Map<String, dynamic> map,
) {
  if (map['signer'] is! String || map['sig'] is! Map<String, dynamic>) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON with top-level signer and nested sig.',
    );
  }
  return SignedOffchainAttestation.fromJson(map);
}

dynamic _jsonSafeValue(dynamic value, [String? parentKey]) {
  if (value is BigInt) {
    if (parentKey == 'time' ||
        parentKey == 'expirationTime' ||
        parentKey == 'version') {
      return value.toInt();
    }
    return value.toString();
  }
  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(
        key,
        _jsonSafeValue(nestedValue, key.toString()),
      ),
    );
  }
  if (value is List) {
    return value.map((item) => _jsonSafeValue(item, parentKey)).toList();
  }
  return value;
}
```

Notes for implementation:
- Do not strip `types['EIP712Domain']`.
- Preserve the canonical top-level `signer` + nested `sig` shape exactly.
- Leave bytes/hex fields such as `schema`, `data`, `salt`, `uid`, `r`, and `s` as strings.

- [ ] **Step 4: Run the targeted tests again**

Run: `flutter test test/screens/verify_screen_parsing_test.dart test/protocol/round_trip_test.dart`

Expected: PASS. The adapter should now round-trip canonical EAS JSON and the legacy flat-shape expectations should be gone.

- [ ] **Step 5: Commit the adapter change**

```bash
git add lib/utils/attestation_json.dart test/screens/verify_screen_parsing_test.dart test/protocol/round_trip_test.dart
git commit -m "feat: use canonical eas offchain json"
```

### Task 2: Update the signed-result card to display and copy canonical EAS JSON

**Files:**
- Modify: `lib/widgets/attestation_result_card.dart`
- Modify: `test/widgets/attestation_result_card_test.dart`

- [ ] **Step 1: Write the failing widget test for canonical clipboard export**

Replace the current widget test body in `test/widgets/attestation_result_card_test.dart` with expectations that reflect canonical JSON and the new copy messaging:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/widgets/attestation_result_card.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('copy full result exports canonical EAS JSON', (tester) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardText};
        }
        return null;
      },
    );

    final service = AttestationService(
      signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
      chainId: 11155111,
      rpcUrl: 'https://unused.rpc',
    );

    final attestation = await service.signOffchain(
      lat: 37.7749,
      lng: -122.4194,
      memo: 'copy me',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AttestationResultCard(attestation: attestation)),
      ),
    );

    expect(find.text('Schema UID'), findsOneWidget);
    expect(find.text('Offchain Version'), findsOneWidget);
    expect(find.text('Copy EAS JSON'), findsOneWidget);

    await tester.tap(find.text('Copy EAS JSON'));
    await tester.pump();

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final parsed = jsonDecode(clipboardData!.text!) as Map<String, dynamic>;
    final sig = parsed['sig'] as Map<String, dynamic>;

    expect(parsed['signer'], attestation.signer);
    expect(sig['uid'], attestation.uid);
    expect(sig['message'], isA<Map<String, dynamic>>());
    expect(find.text('Attestation copied to clipboard as EAS JSON'), findsOneWidget);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}
```

- [ ] **Step 2: Run the widget test and confirm it fails**

Run: `flutter test test/widgets/attestation_result_card_test.dart`

Expected: FAIL because the widget still references removed flat getters and the button/snackbar text still refer to the old generic JSON export.

- [ ] **Step 3: Update `lib/widgets/attestation_result_card.dart`**

Keep the card minimal, but swap obsolete getters for the new projections exposed by `SignedOffchainAttestation`, and make the copy affordance explicitly canonical-EAS oriented:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location_protocol/location_protocol.dart';

import '../utils/attestation_json.dart';

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
            _row(
              'Time',
              DateTime.fromMillisecondsSinceEpoch(
                attestation.time.toInt() * 1000,
              ).toIso8601String(),
            ),
            _row('Offchain Version', attestation.offchainVersion.toString()),
            _row('Salt', attestation.saltHex ?? '—'),
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
                label: const Text('Copy EAS JSON'),
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
            width: 120,
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

  void _copyToClipboard(BuildContext context) {
    final text = encodeSignedOffchainAttestationJson(attestation);

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Attestation copied to clipboard as EAS JSON'),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the widget test again**

Run: `flutter test test/widgets/attestation_result_card_test.dart`

Expected: PASS. The widget should render stable derived fields and copy canonical EAS JSON.

- [ ] **Step 5: Commit the result-card update**

```bash
git add lib/widgets/attestation_result_card.dart test/widgets/attestation_result_card_test.dart
git commit -m "feat: export canonical eas attestation json"
```

### Task 3: Update verify-screen messaging and end-to-end verification expectations

**Files:**
- Modify: `lib/screens/verify_screen.dart`
- Create: `test/screens/verify_screen_test.dart`
- Modify: `walkthrough.md`

- [ ] **Step 1: Write the failing verification-screen expectations**

Create `test/screens/verify_screen_test.dart` so the user-facing copy is exercised directly in a widget test:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/screens/verify_screen.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

void main() {
  testWidgets('verify screen explains canonical EAS JSON input', (
    tester,
  ) async {
    final service = AttestationService(
      signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
      chainId: 11155111,
      rpcUrl: 'https://unused.rpc',
    );

    await tester.pumpWidget(
      MaterialApp(home: VerifyScreen(service: service)),
    );

    expect(
      find.text('Paste canonical EAS offchain attestation JSON to verify it.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('{"signer":"0x...","sig":'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run the widget test and verify it fails against the stale copy**

Run: `flutter test test/screens/verify_screen_test.dart`

Expected: FAIL because the screen still mentions a generic attestation JSON payload and shows the old flat-shape hint.

- [ ] **Step 3: Update `lib/screens/verify_screen.dart` and `walkthrough.md`**

Refresh the verification copy so it names the canonical EAS envelope and stops suggesting the old flat JSON shape:

```dart
const Text('Paste canonical EAS offchain attestation JSON to verify it.'),
...
decoration: const InputDecoration(
  labelText: 'Attestation JSON',
  border: OutlineInputBorder(),
  hintText:
      '{"signer":"0x...","sig":{"domain":{...},"primaryType":"Attest",...}}',
),
```

Update the verify flow description in `walkthrough.md` to:

```markdown
### Verify Offchain

HomeScreen
  → VerifyScreen
  → User pastes canonical EAS JSON
  → Package-backed JSON parsing → SignedOffchainAttestation
  → AttestationService.verifyOffchain()
      → OffchainSigner.verifyOffchainAttestation()  # library verifies preserved payload
  → Display VerificationResult (isValid, recoveredAddress)
```

Keep the selected-chain behavior unchanged. Do not add auto-detection logic in this task.

- [ ] **Step 4: Run the focused tests and analyzer**

Run:
- `flutter test test/screens/verify_screen_test.dart`
- `flutter analyze`

Expected: PASS. The app should compile cleanly, and the verify flow text should now describe canonical EAS JSON.

- [ ] **Step 5: Commit the verification/docs update**

```bash
git add lib/screens/verify_screen.dart walkthrough.md test/screens/verify_screen_test.dart
git commit -m "docs: align verify flow with eas json envelope"
```

### Task 4: Final regression sweep for sign → copy → paste → verify

**Files:**
- Modify: `test/protocol/attestation_service_test.dart`
- Modify: `test/protocol/round_trip_test.dart`
- Verify only: `lib/screens/sign_screen.dart`

- [ ] **Step 1: Add the final regression test coverage**

Add one end-to-end assertion in `test/protocol/attestation_service_test.dart` proving that canonical exported JSON remains locally verifiable when decoded back into a `SignedOffchainAttestation`:

```dart
import 'package:location_protocol_flutter_app/utils/attestation_json.dart';

...

test('canonical exported JSON verifies after decode', () async {
  final signed = await service.signOffchain(
    lat: 51.5074,
    lng: -0.1278,
    memo: 'canonical export verify',
  );

  final encoded = encodeSignedOffchainAttestationJson(signed);
  final restored = decodeSignedOffchainAttestationJson(encoded);
  final verification = service.verifyOffchain(restored);

  expect(verification.isValid, isTrue);
  expect(
    verification.recoveredAddress.toLowerCase(),
    signed.signer.toLowerCase(),
  );
});
```

In `test/protocol/round_trip_test.dart`, keep the sign-flow checks focused on signing behavior and remove any remaining flat-shape assumptions.

- [ ] **Step 2: Run the broader offchain test set**

Run: `flutter test test/protocol test/screens/verify_screen_parsing_test.dart test/widgets/attestation_result_card_test.dart`

Expected: PASS. This verifies the adapter, protocol service, result card, and verify parsing all agree on the canonical EAS envelope.

- [ ] **Step 3: Review `lib/screens/sign_screen.dart` and make no functional change unless copy text is stale**

Use this checklist while reviewing `lib/screens/sign_screen.dart`:

```dart
// No signing-pipeline change is expected here.
// Only update text if the surrounding UI still implies a legacy flat JSON export.
// The actual export behavior lives in AttestationResultCard.
```

If no stale wording is present, leave `lib/screens/sign_screen.dart` untouched.

- [ ] **Step 4: Run the full verification commands**

Run:
- `flutter test`
- `flutter analyze`

Expected: PASS. No compile errors should remain for removed flat-model getters, and canonical export/import should be covered by tests.

- [ ] **Step 5: Commit the regression sweep**

```bash
git add test/protocol/attestation_service_test.dart test/protocol/round_trip_test.dart
git commit -m "test: cover canonical eas offchain round trip"
```
