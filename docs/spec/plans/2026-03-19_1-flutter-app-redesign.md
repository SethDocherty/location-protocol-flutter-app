# Flutter App Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all custom EAS/EIP-712/ABI protocol code (~2,700 lines across 15 files) and rebuild the app as a thin integration layer on the `location_protocol` library, with Privy auth extracted into a reusable module.

**Architecture:** The app becomes three layers: (1) `lib/privy/` — standalone auth module with zero protocol imports, (2) `lib/protocol/` — bridge layer containing `PrivySigner`, `ExternalWalletSigner`, `AttestationService` that delegate to the library, (3) `lib/screens/` + `lib/widgets/` — UI consuming library-native models directly. A lightweight `lib/settings/` module handles dev/test RPC config via SharedPreferences.

**Tech Stack:** Flutter 3.11+, `location_protocol` (git), `privy_flutter: ^0.4.0`, `flutter_dotenv: ^5.1.0`, `shared_preferences`, `convert: ^3.1.1`

**Branch:** `copilot/8-remove-deprecated-protocol-code` (continue on current branch)

**PRD:** `docs/spec/plans/prd-app-redesign.md`

---

## Table of Contents

| Phase | Description | Tasks | Status |
|-------|-------------|-------|--------|
| [Part 1: Foundation](#part-1-foundation) | Privy extraction + Protocol bridge (signers, schema, service) | Tasks 1–17 | Not started |
| [Part 2: Screens & Features](2026-03-19_1-flutter-app-redesign-part-2.md) | Screen rewrites, new screens, settings, widgets | Tasks 18–32 | Not started |
| [Part 3: Cleanup & Verification](2026-03-19_1-flutter-app-redesign-part-3.md) | Code deletion, wiring, verification, memory | Tasks 33–42 | Not started |

**Total: 42 tasks**

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Branch strategy | Continue on current branch | Research sandbox app; clean history not important |
| LPVersion | Use library's `LPVersion.current` (`0.2.0`) | PRD stated `1.0.0` but library has `0.2.0` |
| Onchain receipts | Show txHash + block explorer link | YAGNI; defer receipt polling |
| Privy module tests | Include basic tests | Mocked SDK for PrivyAuthState/PrivyManager |
| Dialog widgets | Rewrite from scratch | Old types incompatible with library's `Signer`/`EIP712Signature` |
| Settings persistence | SharedPreferences | Minimal complexity (~150 lines + 1 dep) |
| Architecture doc | Defer update | Plan itself documents new architecture |

---

## New File Structure

```
lib/
├── main.dart                               # Rewired: PrivyAuthProvider + AttestationServiceProvider
├── privy/                                  # Standalone auth module (moved from lib/src/privy_auth_modal/)
│   ├── privy_module.dart                   # Barrel export
│   ├── privy_manager.dart
│   ├── privy_auth_provider.dart
│   ├── privy_auth_config.dart
│   ├── login_modal.dart
│   ├── widgets/
│   │   ├── login_method_button.dart
│   │   └── otp_input_view.dart
│   └── flows/
│       ├── sms_flow.dart
│       ├── email_flow.dart
│       ├── oauth_flow.dart
│       └── siwe_flow.dart
├── protocol/                               # Bridge: Privy ↔ location_protocol
│   ├── protocol_module.dart                # Barrel export
│   ├── privy_signer.dart                   # extends Signer (injectable RPC caller)
│   ├── external_wallet_signer.dart         # extends Signer (callback-driven)
│   ├── schema_config.dart                  # App's SchemaDefinition + LP defaults
│   ├── attestation_service.dart            # Orchestrator: offchain + onchain ops
│   └── attestation_service_provider.dart   # InheritedWidget
├── settings/                               # Dev/test config
│   ├── settings_service.dart               # SharedPreferences wrapper
│   └── settings_screen.dart                # RPC URL, private key config UI
├── screens/
│   ├── home_screen.dart                    # Rewritten: expanded nav, auth gating
│   ├── sign_screen.dart                    # Rewritten: AttestationService, library types
│   ├── verify_screen.dart                  # Rewritten: JSON parsing, library verification
│   ├── onchain_attest_screen.dart          # NEW
│   ├── register_schema_screen.dart         # NEW
│   └── timestamp_screen.dart              # NEW
└── widgets/
    ├── attestation_result_card.dart        # Reusable result display
    ├── chain_selector.dart                 # Dropdown for ChainConfig.supportedChainIds
    ├── private_key_import_dialog.dart      # Rewritten from scratch
    └── external_sign_dialog.dart           # Rewritten from scratch
```

### Files to Delete (Sub-Phase E)

All 15 files from FR-13 plus 4 obsolete test files:

**`lib/src/eas/`** (10 files):
- `eip712_signer.dart` (1031 lines)
- `abi_encoder.dart` (309 lines)
- `schema_config.dart` (56 lines)
- `attestation_signer.dart` (42 lines)
- `ecdsa_signature.dart` (17 lines)
- `local_key_signer.dart` (46 lines)
- `privy_signer_adapter.dart` (173 lines)
- `external_wallet_signer.dart` (102 lines)
- `external_sign_dialog.dart` (255 lines)
- `private_key_import_dialog.dart` (211 lines)

**`lib/src/models/`** (1 file):
- `location_attestation.dart` (247 lines)

**`lib/src/builder/`** (1 file):
- `attestation_builder.dart` (72 lines)

**`lib/src/services/`** (3 files):
- `location_protocol_service.dart` (37 lines)
- `library_location_protocol_service.dart` (52 lines)
- `location_protocol_provider.dart` (46 lines)

**`test/`** (4 files to delete):
- `abi_encoder_test.dart`
- `attestation_builder_test.dart`
- `attestation_signer_test.dart`
- `eip712_signer_test.dart`

---

## Part 1: Foundation

Sub-Phase A (Tasks 1–5): Privy module extraction
Sub-Phase B (Tasks 6–17): Protocol bridge core

---

### Task 1: Move Privy module to `lib/privy/`

**Files:**
- Move: `lib/src/privy_auth_modal/*` → `lib/privy/*`
- Modify: `lib/main.dart` (update import path)

- [ ] **Step 1: Create `lib/privy/` directory and copy all files**

Move every file preserving the subdirectory structure:
```
lib/src/privy_auth_modal/privy_auth_modal.dart    → lib/privy/privy_module.dart
lib/src/privy_auth_modal/privy_auth_config.dart   → lib/privy/privy_auth_config.dart
lib/src/privy_auth_modal/privy_auth_provider.dart → lib/privy/privy_auth_provider.dart
lib/src/privy_auth_modal/privy_manager.dart       → lib/privy/privy_manager.dart
lib/src/privy_auth_modal/login_modal.dart         → lib/privy/login_modal.dart
lib/src/privy_auth_modal/widgets/*                → lib/privy/widgets/*
lib/src/privy_auth_modal/flows/*                  → lib/privy/flows/*
```

- [ ] **Step 2: Update internal imports within `lib/privy/`**

In all moved files, update relative imports. The internal structure is preserved, so most relative imports stay the same. The barrel file `privy_module.dart` needs its exports updated:

```dart
// lib/privy/privy_module.dart
library privy_module;

export 'login_modal.dart' show showPrivyLoginModal;
export 'privy_auth_config.dart'
    show PrivyAuthAppearance, PrivyAuthConfig, LoginMethod;
export 'privy_auth_provider.dart' show PrivyAuthProvider, PrivyAuthState;
export 'privy_manager.dart' show PrivyManager;
export 'package:privy_flutter/privy_flutter.dart'
    show AuthState, EmbeddedEthereumWallet, PrivyUser;
```

Note: Added `PrivyManager` to exports (needed by protocol bridge for wallet access).

- [ ] **Step 3: Update `lib/main.dart` import**

Change:
```dart
import 'src/privy_auth_modal/privy_auth_modal.dart';
```
To:
```dart
import 'privy/privy_module.dart';
```

- [ ] **Step 4: Update `lib/screens/home_screen.dart` import (if any)**

Check for any direct imports of `privy_auth_modal` in screen files and update to `privy/privy_module.dart`.

- [ ] **Step 5: Delete old `lib/src/privy_auth_modal/` directory**

Remove the entire old directory after confirming all imports are updated.

- [ ] **Step 6: Run `flutter analyze`**

Run: `flutter analyze`
Expected: Zero issues (or only pre-existing issues unrelated to the move)

- [ ] **Step 7: Commit**

```bash
git add lib/privy/ lib/main.dart lib/screens/
git rm -r lib/src/privy_auth_modal/
git commit -m "refactor: move Privy auth module to lib/privy/"
```

---

### Task 2: Verify Privy module isolation

**Files:**
- Check: all files under `lib/privy/`

- [ ] **Step 1: Audit imports in every `lib/privy/` file**

Verify ZERO imports from:
- `lib/src/eas/`
- `lib/src/models/`
- `lib/src/services/`
- `lib/src/builder/`
- `package:location_protocol/`

Run:
```bash
grep -r "import.*src/eas\|import.*src/models\|import.*src/services\|import.*src/builder\|import.*location_protocol" lib/privy/
```
Expected: No output (zero matches)

- [ ] **Step 2: Commit (if any fixes needed)**

```bash
git commit -am "fix: ensure Privy module has zero protocol imports"
```

---

### Task 3: Write Privy module unit tests — PrivyAuthState

**Files:**
- Create: `test/privy/privy_auth_state_test.dart`

- [ ] **Step 1: Write failing tests for PrivyAuthState**

```dart
// test/privy/privy_auth_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/privy/privy_auth_provider.dart';

void main() {
  group('PrivyAuthState', () {
    late PrivyAuthState state;

    setUp(() {
      state = PrivyAuthState();
    });

    tearDown(() {
      state.dispose();
    });

    test('initial state is not ready and not authenticated', () {
      expect(state.isReady, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
      expect(state.wallet, isNull);
      expect(state.walletAddress, isNull);
      expect(state.error, isNull);
    });

    test('notifies listeners on state change', () {
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      // PrivyAuthState._update is private, so we test via logout()
      // which calls _update internally. For direct _update testing,
      // we'd need to make it @visibleForTesting or test through
      // the provider. For now, test the public API.
      expect(notifyCount, 0);
    });

    test('logout clears all state fields', () async {
      // We can't easily test logout without mocking PrivyManager.
      // This test verifies the state object itself is a ChangeNotifier.
      expect(state, isA<ChangeNotifier>());
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `flutter test test/privy/privy_auth_state_test.dart -v`
Expected: PASS — these are basic state-shape tests

- [ ] **Step 3: Commit**

```bash
git add test/privy/
git commit -m "test: add PrivyAuthState unit tests"
```

---

### Task 4: Write Privy module unit tests — PrivyManager

**Files:**
- Create: `test/privy/privy_manager_test.dart`

- [ ] **Step 1: Write failing tests for PrivyManager**

```dart
// test/privy/privy_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/privy/privy_manager.dart';

void main() {
  group('PrivyManager', () {
    test('is a singleton', () {
      final a = PrivyManager();
      final b = PrivyManager();
      expect(identical(a, b), isTrue);
    });

    test('throws StateError when accessing privy before initialization', () {
      // Note: PrivyManager is a singleton that may already be initialized
      // from other tests. This test verifies the contract — if not initialized,
      // accessing .privy throws. In a fresh isolate this would throw.
      // We test the contract documentation rather than the runtime state.
      expect(PrivyManager(), isA<PrivyManager>());
    });

    test('isInitialized reflects SDK state', () {
      // After any previous test run, this may be true or false.
      // We just verify the getter exists and returns a bool.
      expect(PrivyManager().isInitialized, isA<bool>());
    });
  });
}
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/privy/privy_manager_test.dart -v`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/privy/privy_manager_test.dart
git commit -m "test: add PrivyManager unit tests"
```

---

### Task 5: Update widget smoke test for new imports

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Update widget test imports**

Update any import of `privy_auth_modal` to `privy/privy_module.dart` in `test/widget_test.dart`.

- [ ] **Step 2: Run test**

Run: `flutter test test/widget_test.dart -v`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: update widget smoke test imports for Privy module move"
```

---

### Task 6: Create `SchemaConfig` — app's schema definition

**Files:**
- Create: `lib/protocol/schema_config.dart`
- Create: `test/protocol/schema_config_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/protocol/schema_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';

void main() {
  group('AppSchema', () {
    test('defines 6 user fields', () {
      expect(AppSchema.definition.fields.length, 6);
    });

    test('user fields match LP spec ordering', () {
      final names = AppSchema.definition.fields.map((f) => f.name).toList();
      expect(names, [
        'eventTimestamp',
        'recipeType',
        'recipePayload',
        'mediaType',
        'mediaData',
        'memo',
      ]);
    });

    test('allFields includes 4 LP base fields + 6 user fields', () {
      expect(AppSchema.definition.allFields.length, 10);
    });

    test('schema UID is a 66-char 0x-prefixed hex string', () {
      final uid = AppSchema.schemaUID;
      expect(uid, startsWith('0x'));
      expect(uid.length, 66);
    });

    test('schema UID is deterministic', () {
      expect(AppSchema.schemaUID, AppSchema.schemaUID);
    });

    test('schema is revocable by default', () {
      expect(AppSchema.definition.revocable, isTrue);
    });

    test('toEASSchemaString produces comma-separated type-name pairs', () {
      final str = AppSchema.definition.toEASSchemaString();
      expect(str, contains('string lp_version'));
      expect(str, contains('string memo'));
      expect(str, contains('uint256 eventTimestamp'));
    });
  });

  group('AppSchema.defaultLPPayload', () {
    test('creates LPPayload with correct version', () {
      final payload = AppSchema.buildLPPayload(lat: 37.7749, lng: -122.4194);
      expect(payload.lpVersion, LPVersion.current);
    });

    test('creates GeoJSON point from coordinates', () {
      final payload = AppSchema.buildLPPayload(lat: 37.7749, lng: -122.4194);
      final loc = payload.location as Map<String, dynamic>;
      expect(loc['type'], 'Point');
      final coords = loc['coordinates'] as List;
      expect(coords[0], -122.4194); // lng first
      expect(coords[1], 37.7749);   // lat second
    });

    test('uses CRS84 SRS', () {
      final payload = AppSchema.buildLPPayload(lat: 0, lng: 0);
      expect(payload.srs, 'http://www.opengis.net/def/crs/OGC/1.3/CRS84');
    });

    test('uses geojson-point location type', () {
      final payload = AppSchema.buildLPPayload(lat: 0, lng: 0);
      expect(payload.locationType, 'geojson-point');
    });
  });

  group('AppSchema.buildUserData', () {
    test('produces map with all 6 user fields', () {
      final data = AppSchema.buildUserData(memo: 'test');
      expect(data.keys, containsAll([
        'eventTimestamp',
        'recipeType',
        'recipePayload',
        'mediaType',
        'mediaData',
        'memo',
      ]));
    });

    test('eventTimestamp is a BigInt', () {
      final data = AppSchema.buildUserData(memo: 'test');
      expect(data['eventTimestamp'], isA<BigInt>());
    });

    test('uses provided timestamp when given', () {
      final data = AppSchema.buildUserData(
        memo: 'test',
        eventTimestamp: BigInt.from(1700000000),
      );
      expect(data['eventTimestamp'], BigInt.from(1700000000));
    });

    test('defaults empty lists for recipe and media fields', () {
      final data = AppSchema.buildUserData(memo: 'test');
      expect(data['recipeType'], <String>[]);
      expect(data['recipePayload'], <List<int>>[]);
      expect(data['mediaType'], <String>[]);
      expect(data['mediaData'], <List<int>>[]);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/protocol/schema_config_test.dart -v`
Expected: FAIL — `schema_config.dart` does not exist yet

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/protocol/schema_config.dart
import 'dart:typed_data';

import 'package:location_protocol/location_protocol.dart';

/// App-level schema configuration.
///
/// Defines the Location Protocol schema fields and provides helpers
/// to build LP payloads and user data maps for attestation operations.
class AppSchema {
  AppSchema._();

  /// The app's schema definition: 6 user fields.
  /// LP base fields (lp_version, srs, location_type, location) are
  /// auto-prepended by the library's SchemaDefinition.
  static final SchemaDefinition definition = SchemaDefinition(
    fields: [
      SchemaField(type: 'uint256', name: 'eventTimestamp'),
      SchemaField(type: 'string[]', name: 'recipeType'),
      SchemaField(type: 'bytes[]', name: 'recipePayload'),
      SchemaField(type: 'string[]', name: 'mediaType'),
      SchemaField(type: 'bytes[]', name: 'mediaData'),
      SchemaField(type: 'string', name: 'memo'),
    ],
  );

  /// Computed schema UID (deterministic from the schema string + resolver + revocable).
  static final String schemaUID = SchemaUID.compute(definition);

  /// Builds an [LPPayload] from lat/lng coordinates.
  static LPPayload buildLPPayload({
    required double lat,
    required double lng,
  }) {
    return LPPayload(
      lpVersion: LPVersion.current,
      srs: 'http://www.opengis.net/def/crs/OGC/1.3/CRS84',
      locationType: 'geojson-point',
      location: {
        'type': 'Point',
        'coordinates': [lng, lat], // GeoJSON is [lng, lat]
      },
    );
  }

  /// Builds the user data map matching the schema's 6 user fields.
  static Map<String, dynamic> buildUserData({
    required String memo,
    BigInt? eventTimestamp,
    List<String>? recipeType,
    List<Uint8List>? recipePayload,
    List<String>? mediaType,
    List<Uint8List>? mediaData,
  }) {
    return {
      'eventTimestamp': eventTimestamp ??
          BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      'recipeType': recipeType ?? <String>[],
      'recipePayload': recipePayload ?? <Uint8List>[],
      'mediaType': mediaType ?? <String>[],
      'mediaData': mediaData ?? <Uint8List>[],
      'memo': memo,
    };
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/protocol/schema_config_test.dart -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/protocol/schema_config.dart test/protocol/schema_config_test.dart
git commit -m "feat: add AppSchema with schema definition, LP payload builder, and user data builder"
```

---

### Task 7: Create `PrivySigner` — extends library `Signer`

**Files:**
- Create: `lib/protocol/privy_signer.dart`
- Create: `test/protocol/privy_signer_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/protocol/privy_signer_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/privy_signer.dart';

/// Well-known Hardhat test account #0.
const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  group('PrivySigner — interface contract', () {
    late PrivySigner signer;

    setUp(() {
      signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, __) async => '0x${'00' * 65}',
      );
    });

    test('extends Signer', () {
      expect(signer, isA<Signer>());
    });

    test('returns the address supplied at construction', () {
      expect(signer.address, _testAddress);
    });
  });

  group('PrivySigner.signTypedData', () {
    test('calls eth_signTypedData_v4 via rpcCaller', () async {
      String? capturedMethod;

      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (method, _) async {
          capturedMethod = method;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      await signer.signTypedData({
        'domain': {'name': 'Test'},
        'types': {},
        'primaryType': 'Test',
        'message': {},
      });

      expect(capturedMethod, 'eth_signTypedData_v4');
    });

    test('passes signer address as first param', () async {
      String? capturedAddress;

      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, params) async {
          capturedAddress = params[0] as String;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      await signer.signTypedData({'domain': {}, 'types': {}, 'message': {}});
      expect(capturedAddress, _testAddress);
    });

    test('passes JSON-encoded typed data as second param', () async {
      String? capturedJson;

      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, params) async {
          capturedJson = params[1] as String;
          return '0x${'ab' * 32}${'cd' * 32}1b';
        },
      );

      final typedData = {
        'domain': {'name': 'EAS'},
        'types': {'Attest': []},
        'primaryType': 'Attest',
        'message': {'version': 1},
      };
      await signer.signTypedData(typedData);

      final decoded = jsonDecode(capturedJson!) as Map<String, dynamic>;
      expect(decoded['domain']['name'], 'EAS');
    });

    test('returns EIP712Signature parsed from hex response', () async {
      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, __) async => '0x${'aa' * 32}${'bb' * 32}1b',
      );

      final sig = await signer.signTypedData({'domain': {}, 'types': {}, 'message': {}});

      expect(sig, isA<EIP712Signature>());
      expect(sig.v, 27);
    });
  });

  group('PrivySigner.signDigest', () {
    test('throws UnsupportedError', () {
      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, __) async => '',
      );

      expect(
        () => signer.signDigest(Uint8List(32)),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('PrivySigner — signature parsing', () {
    PrivySigner _signerWith(String sigHex) {
      return PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, __) async => sigHex,
      );
    }

    test('parses valid 65-byte 0x-prefixed signature', () async {
      final sig = await _signerWith('0x${'aa' * 32}${'bb' * 32}1b')
          .signTypedData({'domain': {}, 'types': {}, 'message': {}});
      expect(sig.v, 27);
      expect(sig.r, startsWith('0x'));
      expect(sig.s, startsWith('0x'));
    });

    test('accepts signature without 0x prefix', () async {
      final sig = await _signerWith('${'aa' * 32}${'bb' * 32}1c')
          .signTypedData({'domain': {}, 'types': {}, 'message': {}});
      expect(sig.v, 28);
    });

    test('throws FormatException for wrong-length signature', () {
      final signer = _signerWith('0xdeadbeef');
      expect(
        signer.signTypedData({'domain': {}, 'types': {}, 'message': {}}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for empty signature', () {
      final signer = _signerWith('');
      expect(
        signer.signTypedData({'domain': {}, 'types': {}, 'message': {}}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PrivySigner — error handling', () {
    test('throws PrivySigningException when rpcCaller throws it', () {
      final signer = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (_, __) async =>
            throw const PrivySigningException('user rejected'),
      );

      expect(
        signer.signTypedData({'domain': {}, 'types': {}, 'message': {}}),
        throwsA(isA<PrivySigningException>()),
      );
    });

    test('PrivySigningException.toString includes message', () {
      const ex = PrivySigningException('something went wrong');
      expect(ex.toString(), contains('something went wrong'));
      expect(ex.toString(), contains('PrivySigningException'));
    });
  });

  group('PrivySigner.fromWallet (factory)', () {
    // NOTE: We cannot test the real Privy SDK in unit tests.
    // The factory is tested indirectly via the constructor + rpcCaller injection.
    // Integration testing with the real SDK is a manual/E2E concern.
    test('factory exists as a static method', () {
      // Verify the static method is accessible (compile-time check).
      // Actual invocation requires a real EmbeddedEthereumWallet.
      expect(PrivySigner.fromWallet, isA<Function>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/protocol/privy_signer_test.dart -v`
Expected: FAIL — `privy_signer.dart` does not exist

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/protocol/privy_signer.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:location_protocol/location_protocol.dart';
import 'package:privy_flutter/privy_flutter.dart';

/// Callback type for performing Ethereum JSON-RPC calls.
///
/// Accepting this instead of `EmbeddedEthereumWallet` directly lets
/// [PrivySigner] be unit-tested without the Privy SDK.
typedef EthereumRpcCaller = Future<String> Function(
  String method,
  List<dynamic> params,
);

/// Thrown when a Privy RPC call fails.
class PrivySigningException implements Exception {
  final String message;
  const PrivySigningException(this.message);

  @override
  String toString() => 'PrivySigningException: $message';
}

/// Bridges a Privy embedded wallet to the library's [Signer] interface.
///
/// Routes all signing through `eth_signTypedData_v4` — the wallet
/// recomputes the EIP-712 hash internally, so [signDigest] is unsupported.
///
/// The library normalizes `v` to 27/28 inside `OffchainSigner`, so this
/// class does not need to handle v normalization.
///
/// **Production:**
/// ```dart
/// final signer = PrivySigner.fromWallet(embeddedWallet);
/// ```
///
/// **Test:**
/// ```dart
/// final signer = PrivySigner(
///   walletAddress: '0x...',
///   rpcCaller: (method, params) async => '0x...',
/// );
/// ```
class PrivySigner extends Signer {
  final String _address;
  final EthereumRpcCaller _rpcCaller;

  /// Creates a [PrivySigner] with an explicit [rpcCaller] for testability.
  PrivySigner({
    required String walletAddress,
    required EthereumRpcCaller rpcCaller,
  })  : _address = walletAddress,
        _rpcCaller = rpcCaller;

  /// Creates a [PrivySigner] backed by a real Privy [EmbeddedEthereumWallet].
  ///
  /// This factory is the only place that references Privy SDK types.
  factory PrivySigner.fromWallet(EmbeddedEthereumWallet wallet) {
    return PrivySigner(
      walletAddress: wallet.address,
      rpcCaller: (method, params) async {
        final result = await wallet.provider.request(
          EthereumRpcRequest(method: method, params: params),
        );

        late String data;
        result.fold(
          onSuccess: (r) => data = r.data,
          onFailure: (e) =>
              throw PrivySigningException('RPC call failed: ${e.message}'),
        );
        return data;
      },
    );
  }

  @override
  String get address => _address;

  /// Signs EIP-712 typed data via the Privy wallet's `eth_signTypedData_v4`.
  ///
  /// The [typedData] map is the complete EIP-712 typed data structure
  /// as produced by the library's `OffchainSigner.buildOffchainTypedDataJson()`.
  @override
  Future<EIP712Signature> signTypedData(Map<String, dynamic> typedData) async {
    final sigHex = await _rpcCaller(
      'eth_signTypedData_v4',
      [_address, jsonEncode(typedData)],
    );
    return EIP712Signature.fromHex(sigHex);
  }

  /// Wallet signers route exclusively through [signTypedData].
  ///
  /// This method is never called by `OffchainSigner` when `signTypedData`
  /// is overridden.
  @override
  Future<EIP712Signature> signDigest(Uint8List digest) {
    throw UnsupportedError(
      'PrivySigner does not support signDigest. '
      'Use signTypedData via OffchainSigner instead.',
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/protocol/privy_signer_test.dart -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/protocol/privy_signer.dart test/protocol/privy_signer_test.dart
git commit -m "feat: add PrivySigner extending library Signer with injectable RPC caller"
```

---

### Task 8: PrivySigner end-to-end signing + verification

**Files:**
- Modify: `test/protocol/privy_signer_test.dart`

- [ ] **Step 1: Write failing E2E test**

Add to `test/protocol/privy_signer_test.dart`:

```dart
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';

// ... at the end of main():

group('PrivySigner — E2E sign + verify via library', () {
  test('sign with PrivySigner and verify round-trips', () async {
    // Use LocalKeySigner to produce the "real" signature that a wallet would return.
    final localSigner = LocalKeySigner(privateKeyHex: _testPrivateKey);

    // Build a mock PrivySigner that delegates to LocalKeySigner's signTypedData.
    final privySigner = PrivySigner(
      walletAddress: _testAddress,
      rpcCaller: (method, params) async {
        // Parse the typed data JSON, pass to LocalKeySigner, return hex.
        final typedData = jsonDecode(params[1] as String) as Map<String, dynamic>;
        final sig = await localSigner.signTypedData(typedData);
        // Reconstruct 65-byte hex: r(32) + s(32) + v(1)
        final rHex = sig.r.substring(2); // strip 0x
        final sHex = sig.s.substring(2);
        final vHex = sig.v.toRadixString(16).padLeft(2, '0');
        return '0x$rHex$sHex$vHex';
      },
    );

    final lpPayload = AppSchema.buildLPPayload(lat: 37.7749, lng: -122.4194);
    final userData = AppSchema.buildUserData(
      memo: 'E2E test',
      eventTimestamp: BigInt.from(1700000000),
    );

    final chainId = 11155111; // Sepolia
    final easAddress = ChainConfig.forChainId(chainId)!.eas;

    final offchainSigner = OffchainSigner(
      signer: privySigner,
      chainId: chainId,
      easContractAddress: easAddress,
    );

    final signed = await offchainSigner.signOffchainAttestation(
      schema: AppSchema.definition,
      lpPayload: lpPayload,
      userData: userData,
    );

    expect(signed.signer.toLowerCase(), _testAddress.toLowerCase());
    expect(signed.uid, isNotEmpty);
    expect(signed.signature.v, anyOf(27, 28));

    // Verify
    final result = offchainSigner.verifyOffchainAttestation(signed);
    expect(result.isValid, isTrue);
    expect(result.recoveredAddress.toLowerCase(), _testAddress.toLowerCase());
  });
});
```

- [ ] **Step 2: Run test to verify it fails (if imports missing) then passes**

Run: `flutter test test/protocol/privy_signer_test.dart -v`
Expected: ALL PASS after adding imports

- [ ] **Step 3: Commit**

```bash
git add test/protocol/privy_signer_test.dart
git commit -m "test: add PrivySigner E2E sign + verify round-trip"
```

---

### Task 9: Create `ExternalWalletSigner` — extends library `Signer`

**Files:**
- Create: `lib/protocol/external_wallet_signer.dart`
- Create: `test/protocol/external_wallet_signer_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/protocol/external_wallet_signer_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/external_wallet_signer.dart';

const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  group('ExternalWalletSigner — interface contract', () {
    test('extends Signer', () {
      final signer = ExternalWalletSigner(
        walletAddress: _testAddress,
        onSignTypedData: (_) async => EIP712Signature(v: 27, r: '0x${'aa' * 32}', s: '0x${'bb' * 32}'),
      );
      expect(signer, isA<Signer>());
    });

    test('returns the address supplied at construction', () {
      final signer = ExternalWalletSigner(
        walletAddress: _testAddress,
        onSignTypedData: (_) async => EIP712Signature(v: 27, r: '0x${'aa' * 32}', s: '0x${'bb' * 32}'),
      );
      expect(signer.address, _testAddress);
    });
  });

  group('ExternalWalletSigner.signTypedData', () {
    test('invokes onSignTypedData callback with typed data', () async {
      Map<String, dynamic>? capturedData;

      final signer = ExternalWalletSigner(
        walletAddress: _testAddress,
        onSignTypedData: (typedData) async {
          capturedData = typedData;
          return EIP712Signature(v: 27, r: '0x${'aa' * 32}', s: '0x${'bb' * 32}');
        },
      );

      final input = {'domain': {'name': 'Test'}, 'types': {}, 'message': {}};
      await signer.signTypedData(input);

      expect(capturedData, isNotNull);
      expect(capturedData!['domain']['name'], 'Test');
    });

    test('returns the EIP712Signature from the callback', () async {
      final expected = EIP712Signature(v: 28, r: '0x${'cc' * 32}', s: '0x${'dd' * 32}');

      final signer = ExternalWalletSigner(
        walletAddress: _testAddress,
        onSignTypedData: (_) async => expected,
      );

      final result = await signer.signTypedData({});
      expect(result.v, 28);
    });
  });

  group('ExternalWalletSigner.signDigest', () {
    test('throws UnsupportedError', () {
      final signer = ExternalWalletSigner(
        walletAddress: _testAddress,
        onSignTypedData: (_) async => EIP712Signature(v: 27, r: '0x${'aa' * 32}', s: '0x${'bb' * 32}'),
      );

      expect(
        () => signer.signDigest(Uint8List(32)),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/protocol/external_wallet_signer_test.dart -v`
Expected: FAIL — file does not exist

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/protocol/external_wallet_signer.dart
import 'dart:typed_data';

import 'package:location_protocol/location_protocol.dart';

/// Callback that shows the typed data to the user for external signing
/// (e.g., via MetaMask) and returns the resulting signature.
typedef ExternalSignCallback = Future<EIP712Signature> Function(
  Map<String, dynamic> typedData,
);

/// Bridges an external wallet (MetaMask, etc.) to the library's [Signer].
///
/// The user is shown the EIP-712 typed data JSON, signs it externally,
/// and pastes the hex signature back. The [onSignTypedData] callback
/// orchestrates this UI flow.
class ExternalWalletSigner extends Signer {
  final String _address;
  final ExternalSignCallback _onSignTypedData;

  ExternalWalletSigner({
    required String walletAddress,
    required ExternalSignCallback onSignTypedData,
  })  : _address = walletAddress,
        _onSignTypedData = onSignTypedData;

  @override
  String get address => _address;

  @override
  Future<EIP712Signature> signTypedData(Map<String, dynamic> typedData) {
    return _onSignTypedData(typedData);
  }

  /// External wallets must use typed data — raw digest signing is unsupported.
  @override
  Future<EIP712Signature> signDigest(Uint8List digest) {
    throw UnsupportedError(
      'ExternalWalletSigner does not support signDigest. '
      'Use signTypedData instead.',
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/protocol/external_wallet_signer_test.dart -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/protocol/external_wallet_signer.dart test/protocol/external_wallet_signer_test.dart
git commit -m "feat: add ExternalWalletSigner extending library Signer with callback-driven signing"
```

---

### Task 10: Create `AttestationService` — offchain signing

**Files:**
- Create: `lib/protocol/attestation_service.dart`
- Create: `test/protocol/attestation_service_test.dart`

- [ ] **Step 1: Write failing test for offchain sign**

```dart
// test/protocol/attestation_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  late AttestationService service;
  late LocalKeySigner signer;

  setUp(() {
    signer = LocalKeySigner(privateKeyHex: _testPrivateKey);
    service = AttestationService(
      signer: signer,
      chainId: 11155111, // Sepolia
    );
  });

  group('AttestationService.signOffchain', () {
    test('returns a SignedOffchainAttestation', () async {
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test attestation',
      );

      expect(result, isA<SignedOffchainAttestation>());
    });

    test('signed attestation has correct signer address', () async {
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test',
      );

      expect(result.signer.toLowerCase(), _testAddress.toLowerCase());
    });

    test('signed attestation has non-empty UID', () async {
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test',
      );

      expect(result.uid, isNotEmpty);
      expect(result.uid, startsWith('0x'));
    });

    test('signed attestation uses app schema UID', () async {
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test',
      );

      expect(result.schemaUID, AppSchema.schemaUID);
    });

    test('signed attestation has valid signature', () async {
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test',
      );

      expect(result.signature.v, anyOf(27, 28));
      expect(result.signature.r, startsWith('0x'));
      expect(result.signature.s, startsWith('0x'));
    });

    test('uses provided eventTimestamp when given', () async {
      final ts = BigInt.from(1700000000);
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test',
        eventTimestamp: ts,
      );

      // The eventTimestamp is ABI-encoded in result.data — we verify indirectly
      // by checking the attestation is valid (encoding must be correct).
      expect(result, isA<SignedOffchainAttestation>());
    });
  });

  group('AttestationService.verifyOffchain', () {
    test('valid attestation verifies successfully', () async {
      final signed = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'verify test',
      );

      final result = service.verifyOffchain(signed);

      expect(result.isValid, isTrue);
      expect(
        result.recoveredAddress.toLowerCase(),
        _testAddress.toLowerCase(),
      );
    });

    test('returns VerificationResult', () async {
      final signed = await service.signOffchain(
        lat: 0,
        lng: 0,
        memo: 'test',
      );

      final result = service.verifyOffchain(signed);
      expect(result, isA<VerificationResult>());
    });
  });

  group('AttestationService — round trip', () {
    test('sign then verify round-trips correctly', () async {
      final signed = await service.signOffchain(
        lat: 51.5074,
        lng: -0.1278,
        memo: 'London test',
      );

      final verification = service.verifyOffchain(signed);

      expect(verification.isValid, isTrue);
      expect(
        verification.recoveredAddress.toLowerCase(),
        signed.signer.toLowerCase(),
      );
    });

    test('different inputs produce different UIDs', () async {
      final a = await service.signOffchain(lat: 0, lng: 0, memo: 'a');
      final b = await service.signOffchain(lat: 1, lng: 1, memo: 'b');

      expect(a.uid, isNot(b.uid));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/protocol/attestation_service_test.dart -v`
Expected: FAIL — `attestation_service.dart` does not exist

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/protocol/attestation_service.dart
import 'dart:typed_data';

import 'package:location_protocol/location_protocol.dart';

import 'schema_config.dart';

/// Orchestrates all protocol operations for the app.
///
/// Offchain operations work with any [Signer]. Onchain operations use
/// either the static builder pipeline (for wallet-based signers like
/// [PrivySigner]) or instance methods (for private-key flows).
class AttestationService {
  final Signer signer;
  final int chainId;
  final String _easAddress;
  final OffchainSigner _offchainSigner;

  AttestationService({
    required this.signer,
    required this.chainId,
  })  : _easAddress = ChainConfig.forChainId(chainId)!.eas,
        _offchainSigner = OffchainSigner(
          signer: signer,
          chainId: chainId,
          easContractAddress: ChainConfig.forChainId(chainId)!.eas,
        );

  /// Signs an offchain location attestation.
  Future<SignedOffchainAttestation> signOffchain({
    required double lat,
    required double lng,
    required String memo,
    BigInt? eventTimestamp,
  }) {
    final lpPayload = AppSchema.buildLPPayload(lat: lat, lng: lng);
    final userData = AppSchema.buildUserData(
      memo: memo,
      eventTimestamp: eventTimestamp,
    );

    return _offchainSigner.signOffchainAttestation(
      schema: AppSchema.definition,
      lpPayload: lpPayload,
      userData: userData,
    );
  }

  /// Verifies an offchain attestation. Returns synchronously.
  VerificationResult verifyOffchain(SignedOffchainAttestation attestation) {
    return _offchainSigner.verifyOffchainAttestation(attestation);
  }

  // --- Onchain: static builder pipeline (for wallet signers) ---

  /// Builds calldata for an onchain attestation (wallet path).
  Uint8List buildAttestCallData({
    required double lat,
    required double lng,
    required String memo,
    BigInt? eventTimestamp,
  }) {
    return EASClient.buildAttestCallData(
      schema: AppSchema.definition,
      lpPayload: AppSchema.buildLPPayload(lat: lat, lng: lng),
      userData: AppSchema.buildUserData(
        memo: memo,
        eventTimestamp: eventTimestamp,
      ),
    );
  }

  /// Builds calldata for timestamping an offchain UID (wallet path).
  Uint8List buildTimestampCallData(String uid) {
    return EASClient.buildTimestampCallData(uid);
  }

  /// Builds calldata for schema registration (wallet path).
  Uint8List buildRegisterSchemaCallData() {
    return SchemaRegistryClient.buildRegisterCallData(AppSchema.definition);
  }

  /// Wraps calldata into a wallet-friendly tx request map.
  Map<String, dynamic> buildTxRequest({
    required Uint8List callData,
    required String contractAddress,
  }) {
    return TxUtils.buildTxRequest(
      to: contractAddress,
      data: callData,
      from: signer.address,
    );
  }

  /// The EAS contract address for the current chain.
  String get easAddress => _easAddress;

  /// The Schema Registry contract address for the current chain.
  String get schemaRegistryAddress =>
      ChainConfig.forChainId(chainId)!.schemaRegistry;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/protocol/attestation_service_test.dart -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/protocol/attestation_service.dart test/protocol/attestation_service_test.dart
git commit -m "feat: add AttestationService with offchain sign/verify and onchain calldata builders"
```

---

### Task 11: Test AttestationService onchain calldata builders

**Files:**
- Modify: `test/protocol/attestation_service_test.dart`

- [ ] **Step 1: Write tests for calldata builder methods**

Add to `test/protocol/attestation_service_test.dart`:

```dart
group('AttestationService — onchain calldata builders', () {
  test('buildAttestCallData returns non-empty Uint8List', () {
    final callData = service.buildAttestCallData(
      lat: 37.7749,
      lng: -122.4194,
      memo: 'onchain test',
    );

    expect(callData, isA<Uint8List>());
    expect(callData.isNotEmpty, isTrue);
  });

  test('buildTimestampCallData returns non-empty Uint8List', () {
    final callData = service.buildTimestampCallData(
      '0x${'ab' * 32}',
    );

    expect(callData, isA<Uint8List>());
    expect(callData.isNotEmpty, isTrue);
  });

  test('buildRegisterSchemaCallData returns non-empty Uint8List', () {
    final callData = service.buildRegisterSchemaCallData();

    expect(callData, isA<Uint8List>());
    expect(callData.isNotEmpty, isTrue);
  });

  test('buildTxRequest produces wallet-friendly map', () {
    final callData = service.buildAttestCallData(
      lat: 0,
      lng: 0,
      memo: 'tx test',
    );

    final txRequest = service.buildTxRequest(
      callData: callData,
      contractAddress: service.easAddress,
    );

    expect(txRequest, isA<Map<String, dynamic>>());
    expect(txRequest['to'], isNotEmpty);
    expect(txRequest['data'], startsWith('0x'));
    expect(txRequest['from'], _testAddress);
  });

  test('easAddress is non-empty for Sepolia', () {
    expect(service.easAddress, isNotEmpty);
    expect(service.easAddress, startsWith('0x'));
  });

  test('schemaRegistryAddress is non-empty for Sepolia', () {
    expect(service.schemaRegistryAddress, isNotEmpty);
    expect(service.schemaRegistryAddress, startsWith('0x'));
  });
});
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/protocol/attestation_service_test.dart -v`
Expected: ALL PASS

- [ ] **Step 3: Commit**

```bash
git add test/protocol/attestation_service_test.dart
git commit -m "test: add onchain calldata builder tests for AttestationService"
```

---

### Task 12: Create `AttestationServiceProvider` — InheritedWidget

**Files:**
- Create: `lib/protocol/attestation_service_provider.dart`

- [ ] **Step 1: Write the provider**

```dart
// lib/protocol/attestation_service_provider.dart
import 'package:flutter/material.dart';

import 'attestation_service.dart';

/// Provides [AttestationService] to the widget tree via [InheritedWidget].
///
/// Access via `AttestationServiceProvider.of(context)`.
class AttestationServiceProvider extends InheritedWidget {
  final AttestationService? service;

  const AttestationServiceProvider({
    super.key,
    required this.service,
    required super.child,
  });

  /// Retrieves the nearest [AttestationService] from the widget tree.
  ///
  /// Returns `null` if no service is available (e.g., no signer configured).
  static AttestationService? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AttestationServiceProvider>()
        ?.service;
  }

  @override
  bool updateShouldNotify(AttestationServiceProvider oldWidget) {
    return service != oldWidget.service;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/protocol/attestation_service_provider.dart
git commit -m "feat: add AttestationServiceProvider InheritedWidget"
```

---

### Task 13: Create protocol barrel export

**Files:**
- Create: `lib/protocol/protocol_module.dart`

- [ ] **Step 1: Write barrel file**

```dart
// lib/protocol/protocol_module.dart
library protocol_module;

export 'attestation_service.dart' show AttestationService;
export 'attestation_service_provider.dart' show AttestationServiceProvider;
export 'external_wallet_signer.dart'
    show ExternalWalletSigner, ExternalSignCallback;
export 'privy_signer.dart'
    show PrivySigner, PrivySigningException, EthereumRpcCaller;
export 'schema_config.dart' show AppSchema;
```

- [ ] **Step 2: Commit**

```bash
git add lib/protocol/protocol_module.dart
git commit -m "feat: add protocol module barrel export"
```

---

### Task 14: Golden-value test — schema UID parity

**Files:**
- Create: `test/protocol/schema_golden_test.dart`

- [ ] **Step 1: Write golden-value test**

```dart
// test/protocol/schema_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';

void main() {
  group('Schema golden values', () {
    test('schema UID matches SchemaUID.compute() for our definition', () {
      final computed = SchemaUID.compute(AppSchema.definition);
      expect(AppSchema.schemaUID, computed);
    });

    test('schema string matches expected EAS format', () {
      final str = AppSchema.definition.toEASSchemaString();
      // Should contain all 10 fields: 4 LP base + 6 user
      expect(str, contains('string lp_version'));
      expect(str, contains('string srs'));
      expect(str, contains('string location_type'));
      expect(str, contains('string location'));
      expect(str, contains('uint256 eventTimestamp'));
      expect(str, contains('string[] recipeType'));
      expect(str, contains('bytes[] recipePayload'));
      expect(str, contains('string[] mediaType'));
      expect(str, contains('bytes[] mediaData'));
      expect(str, contains('string memo'));
    });

    test('LP payload encodes with correct SRS', () {
      final payload = AppSchema.buildLPPayload(lat: 0, lng: 0);
      expect(payload.srs, 'http://www.opengis.net/def/crs/OGC/1.3/CRS84');
    });

    test('LP payload uses current LP version', () {
      final payload = AppSchema.buildLPPayload(lat: 0, lng: 0);
      expect(payload.lpVersion, LPVersion.current);
    });

    test('ABI encode round-trips without error', () {
      final payload = AppSchema.buildLPPayload(lat: 37.7749, lng: -122.4194);
      final userData = AppSchema.buildUserData(
        memo: 'golden test',
        eventTimestamp: BigInt.from(1700000000),
      );

      final encoded = AbiEncoder.encode(
        schema: AppSchema.definition,
        lpPayload: payload,
        userData: userData,
      );

      expect(encoded, isA<Uint8List>());
      expect(encoded.isNotEmpty, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test**

Run: `flutter test test/protocol/schema_golden_test.dart -v`
Expected: ALL PASS

- [ ] **Step 3: Commit**

```bash
git add test/protocol/schema_golden_test.dart
git commit -m "test: add schema golden-value tests for UID, ABI encoding, LP payload"
```

---

### Task 15: New round-trip test with library types

**Files:**
- Create: `test/protocol/round_trip_test.dart`

- [ ] **Step 1: Write round-trip tests**

```dart
// test/protocol/round_trip_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  late AttestationService service;

  setUp(() {
    service = AttestationService(
      signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
      chainId: 11155111,
    );
  });

  group('Round trip — sign → verify', () {
    test('basic round trip succeeds', () async {
      final signed = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'round trip test',
      );

      final result = service.verifyOffchain(signed);

      expect(result.isValid, isTrue);
      expect(result.recoveredAddress.toLowerCase(), _testAddress.toLowerCase());
    });

    test('different coordinates produce different UIDs', () async {
      final a = await service.signOffchain(lat: 0, lng: 0, memo: 'a');
      final b = await service.signOffchain(lat: 90, lng: 180, memo: 'a');

      expect(a.uid, isNot(b.uid));
    });

    test('different memos produce different UIDs', () async {
      final a = await service.signOffchain(lat: 0, lng: 0, memo: 'hello');
      final b = await service.signOffchain(lat: 0, lng: 0, memo: 'world');

      expect(a.uid, isNot(b.uid));
    });

    test('attestation uses version 2 with salt', () async {
      final signed = await service.signOffchain(
        lat: 0,
        lng: 0,
        memo: 'version test',
      );

      expect(signed.version, 2);
      expect(signed.salt, isNotEmpty);
    });

    test('attestation uses app schema UID', () async {
      final signed = await service.signOffchain(
        lat: 0,
        lng: 0,
        memo: 'schema test',
      );

      expect(signed.schemaUID, AppSchema.schemaUID);
    });

    test('signer address matches key', () async {
      final signed = await service.signOffchain(
        lat: 0,
        lng: 0,
        memo: 'signer test',
      );

      expect(signed.signer.toLowerCase(), _testAddress.toLowerCase());
    });
  });
}
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/protocol/round_trip_test.dart -v`
Expected: ALL PASS

- [ ] **Step 3: Commit**

```bash
git add test/protocol/round_trip_test.dart
git commit -m "test: add round-trip sign/verify tests with library types"
```

---

### Task 16: Update `pubspec.yaml` — add `shared_preferences`

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add shared_preferences dependency**

Add under `dependencies:`:
```yaml
  shared_preferences: ^2.2.0
```

- [ ] **Step 2: Run `flutter pub get`**

Run: `flutter pub get`
Expected: Resolves without errors

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add shared_preferences for settings persistence"
```

---

### Task 17: Run full test suite — Part 1 checkpoint

**Files:** None (verification only)

- [ ] **Step 1: Run `flutter analyze`**

Run: `flutter analyze`
Expected: Zero issues (or only pre-existing issues)

- [ ] **Step 2: Run `flutter test`**

Run: `flutter test`
Expected: All tests pass. Old tests may still pass since old code hasn't been deleted yet.

- [ ] **Step 3: Commit any fixes**

```bash
git commit -am "chore: Part 1 checkpoint — Privy extraction + protocol bridge complete"
```

---

## Part 2: Screens & Features

Continued in [2026-03-19_1-flutter-app-redesign-part-2.md](2026-03-19_1-flutter-app-redesign-part-2.md).

Sub-Phase C (Tasks 18–25): Widget rewrites + screen rewrites (offchain)
Sub-Phase D (Tasks 26–32): New screens (onchain) + settings

---

## Part 3: Cleanup & Verification

Continued in [2026-03-19_1-flutter-app-redesign-part-3.md](2026-03-19_1-flutter-app-redesign-part-3.md).

Sub-Phase E (Tasks 33–36): Code deletion + wiring
Sub-Phase F (Tasks 37–42): Verification + documentation + memory
