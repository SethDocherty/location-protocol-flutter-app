# Schema Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a `SchemaProvider` for dynamic active-schema management, build a standalone `SchemaManagerScreen` that replaces `RegisterSchemaScreen`, and refactor signing screens to dynamically render user fields from the active schema.

**Architecture:** A `SchemaProvider` (`ChangeNotifier`) serves as the global source of truth for the active schema definition, computing the UID reactively. A new `SchemaManagerScreen` handles field CRUD, EAS Scan dropdown, and onchain schema registration. Signing screens (`SignScreen`, `OnchainAttestScreen`) will read from `SchemaProvider` to generate dynamic input fields and submit `userData` built from those inputs at runtime.

**Tech Stack:** Flutter / Dart, `provider ^6.x`, `shared_preferences ^2.x`, `http ^1.x`, `location_protocol` (git), `flutter_test`, `mocktail`

---

## Table of Contents

| Task | Component | Description |
|------|-----------|-------------|
| [Task 1](#task-1-schema-provider) | `SchemaProvider` | Core state manager — add, remove, set, reset schema fields |
| [Task 2](#task-2-schema-provider-persistence) | `SchemaProvider` (persistence) | Persist/restore active schema via `SharedPreferences` |
| [Task 3](#task-3-networklinks-helper) | `NetworkLinks` | Add `getEasScanDomain(chainId)` helper |
| [Task 4](#task-4-eas-scan-graphql-query) | `EasScanService` | `queryUserSchemas(address)` via EAS Scan GraphQL |
| [Task 5](#task-5-attestation-service-refactor) | `AttestationService` | Accept dynamic `SchemaDefinition`; add `isSchemaUidRegistered(uid)` |
| [Task 6](#task-6-schema-manager-screen) | `SchemaManagerScreen` | New standalone UI screen + registration migration |
| [Task 7](#task-7-dynamic-fields-in-signing-screens) | `SignScreen` / `OnchainAttestScreen` | Dynamically render user fields from `SchemaProvider` |
| [Task 8](#task-8-main-setup-and-navigation) | `main.dart` / `HomeScreen` | Provide `SchemaProvider` in widget tree; update nav |
| [Task 9](#task-9-cleanup-and-memory) | Cleanup | Delete `RegisterSchemaScreen`, update memory |

---

## Task 1: Schema Provider

**Files:**
- Create: `lib/providers/schema_provider.dart`
- Create: `test/providers/schema_provider_test.dart`

### Key Details

`SchemaProvider` wraps a mutable list of **user** `SchemaField`s. LP base fields (`lp_version`, `srs`, `location_type`, `location`) are managed automatically by `SchemaDefinition` in the library and are never stored here. The `schemaUID` is computed on every mutation by calling `SchemaUID.compute(_definition)`.

```dart
// lib/providers/schema_provider.dart
import 'package:flutter/foundation.dart';
import 'package:location_protocol/location_protocol.dart';

/// Default user-facing fields (LP base fields added automatically by the library).
const List<SchemaField> _defaultUserFields = [
  SchemaField(type: 'uint256', name: 'eventTimestamp'),
  SchemaField(type: 'string[]', name: 'recipeType'),
  SchemaField(type: 'bytes[]', name: 'recipePayload'),
  SchemaField(type: 'string[]', name: 'mediaType'),
  SchemaField(type: 'bytes[]', name: 'mediaData'),
  SchemaField(type: 'string', name: 'memo'),
];

class SchemaProvider extends ChangeNotifier {
  List<SchemaField> _userFields;
  late SchemaDefinition _definition;
  late String _schemaUID;

  SchemaProvider({List<SchemaField>? initialFields})
      : _userFields = List.from(initialFields ?? _defaultUserFields) {
    _rebuild();
  }

  SchemaDefinition get definition => _definition;
  String get schemaUID => _schemaUID;

  /// Returns an unmodifiable snapshot. Use length/name comparisons to detect
  /// changes — do NOT use identity (!=) because a new list instance is returned
  /// on each call.
  List<SchemaField> get userFields => List.unmodifiable(_userFields);

  void addField(SchemaField field) {
    _userFields.add(field);
    _rebuild();
    notifyListeners();
  }

  void removeField(String name) {
    _userFields.removeWhere((f) => f.name == name);
    _rebuild();
    notifyListeners();
  }

  void setSchema(List<SchemaField> fields) {
    _userFields = List.from(fields);
    _rebuild();
    notifyListeners();
  }

  void resetToDefault() {
    _userFields = List.from(_defaultUserFields);
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    _definition = SchemaDefinition(fields: _userFields);
    _schemaUID = SchemaUID.compute(_definition);
  }
}
```

- [ ] **Step 1: Write the failing test**

```dart
// test/providers/schema_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/providers/schema_provider.dart';

void main() {
  group('SchemaProvider', () {
    test('starts with 6 default user fields', () {
      final provider = SchemaProvider();
      expect(provider.userFields.length, 6);
    });

    test('schemaUID is a 66-char 0x-prefixed hex string', () {
      final provider = SchemaProvider();
      expect(provider.schemaUID, startsWith('0x'));
      expect(provider.schemaUID.length, 66);
    });

    test('addField appends a field and updates UID', () {
      final provider = SchemaProvider();
      final originalUID = provider.schemaUID;
      provider.addField(const SchemaField(type: 'string', name: 'newField'));
      expect(provider.userFields.length, 7);
      expect(provider.schemaUID, isNot(originalUID));
    });

    test('removeField removes field by name and updates UID', () {
      final provider = SchemaProvider();
      final originalUID = provider.schemaUID;
      provider.removeField('memo');
      expect(provider.userFields.any((f) => f.name == 'memo'), isFalse);
      expect(provider.schemaUID, isNot(originalUID));
    });

    test('setSchema replaces all fields', () {
      final provider = SchemaProvider();
      provider.setSchema([const SchemaField(type: 'string', name: 'only')]);
      expect(provider.userFields.length, 1);
      expect(provider.userFields.first.name, 'only');
    });

    test('resetToDefault restores 6 default fields', () {
      final provider = SchemaProvider();
      provider.removeField('memo');
      provider.resetToDefault();
      expect(provider.userFields.length, 6);
    });

    test('notifies listeners on mutation', () {
      final provider = SchemaProvider();
      int calls = 0;
      provider.addListener(() => calls++);
      provider.addField(const SchemaField(type: 'bool', name: 'flag'));
      expect(calls, 1);
    });

    test('userFields returns a new list instance each call (safe to compare by value)', () {
      final provider = SchemaProvider();
      expect(identical(provider.userFields, provider.userFields), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/providers/schema_provider_test.dart -v
```
Expected: FAIL — `Error: 'SchemaProvider' is not defined`

- [ ] **Step 3: Create `lib/providers/schema_provider.dart`** with the implementation shown above.

- [ ] **Step 4: Run test to verify it passes**

```
flutter test test/providers/schema_provider_test.dart -v
```
Expected: All 8 tests PASS.

- [ ] **Step 5: Run full test suite to check for regressions**

```
flutter test
```
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/schema_provider.dart test/providers/schema_provider_test.dart
git commit -m "feat: add SchemaProvider for dynamic active-schema management"
```

---

## Task 2: Schema Provider Persistence

**Files:**
- Modify: `lib/providers/schema_provider.dart`
- Modify: `test/providers/schema_provider_test.dart`

### Key Details

Serialize/deserialize `List<SchemaField>` as JSON via `SharedPreferences`. Each field is stored as `{"type": "...", "name": "..."}`. Persistence is offered via:
- `SchemaProvider.load()` — async factory; reads from `SharedPreferences` on startup.
- `save()` — explicit save method called by `main.dart` after each mutation via `unawaited(provider.save())` OR by hooking into mutations.

For clean separation: The provider fires `save()` internally (fire-and-forget) after each mutation. `main.dart` calls `SchemaProvider.load()` once at startup.

The field list JSON key: `schema_provider_fields`.

**Important — `unawaited` import:** Use `dart:async`'s `unawaited()` to discard the future. Import `'dart:async'` at the top of the file.

- [ ] **Step 1: Write failing persistence tests**

Add a new top-level `group` to `test/providers/schema_provider_test.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
// Add this import at the top of the file

// Add inside main(), as a sibling group:
group('SchemaProvider persistence', () {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SchemaProvider.load() returns default when prefs are empty', () async {
    final provider = await SchemaProvider.load();
    expect(provider.userFields.length, 6);
  });

  test('save() and load() round-trips fields', () async {
    final provider = await SchemaProvider.load();
    provider.addField(const SchemaField(type: 'bool', name: 'testFlag'));
    await provider.save();

    final reloaded = await SchemaProvider.load();
    expect(reloaded.userFields.length, 7);
    expect(reloaded.userFields.last.name, 'testFlag');
  });

  test('load() falls back to default on corrupt data', () async {
    SharedPreferences.setMockInitialValues({
      'schema_provider_fields': 'not-valid-json!!!',
    });
    final provider = await SchemaProvider.load();
    expect(provider.userFields.length, 6);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/providers/schema_provider_test.dart -v
```
Expected: FAIL — `SchemaProvider.load` not found.

- [ ] **Step 3: Extend `SchemaProvider` with persistence**

Add at the top of `lib/providers/schema_provider.dart`:
```dart
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
```

Add inside the `SchemaProvider` class:

```dart
static const String _prefsKey = 'schema_provider_fields';

/// Factory constructor that loads the persisted schema from SharedPreferences.
/// Falls back to default if nothing is saved or data is corrupt.
static Future<SchemaProvider> load() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_prefsKey);
  if (json == null) return SchemaProvider();
  try {
    final list = jsonDecode(json) as List<dynamic>;
    final fields = list
        .cast<Map<String, dynamic>>()
        .map((m) => SchemaField(type: m['type'] as String, name: m['name'] as String))
        .toList();
    return SchemaProvider(initialFields: fields);
  } catch (_) {
    return SchemaProvider();
  }
}

/// Persists the current user fields to SharedPreferences.
Future<void> save() async {
  final prefs = await SharedPreferences.getInstance();
  final json = jsonEncode(
    _userFields.map((f) => {'type': f.type, 'name': f.name}).toList(),
  );
  await prefs.setString(_prefsKey, json);
}
```

Also call `unawaited(save())` at the end of each mutation method (`addField`, `removeField`, `setSchema`, `resetToDefault`), after `notifyListeners()`:

```dart
void addField(SchemaField field) {
  _userFields.add(field);
  _rebuild();
  notifyListeners();
  unawaited(save());
}
// ... same pattern for removeField, setSchema, resetToDefault
```

- [ ] **Step 4: Run tests to verify they pass**

```
flutter test test/providers/schema_provider_test.dart -v
```
Expected: All tests PASS (now 11 total).

- [ ] **Step 5: Commit**

```bash
git add lib/providers/schema_provider.dart test/providers/schema_provider_test.dart
git commit -m "feat: persist active schema across app restarts in SchemaProvider"
```

---

## Task 3: NetworkLinks Helper

**Files:**
- Modify: `lib/utils/network_links.dart`
- Modify: `test/utils/network_links_test.dart`

### Key Details

Add `getEasScanDomain(int chainId)` that returns the raw domain string (or `null`) — used by `EasScanService` to construct the GraphQL endpoint. This is a non-`const` static method (the map lookup is not `const`-evaluable at sites that pass a runtime variable).

> **Note:** Do NOT use `const` when calling this method in tests, since `chainId` at test call sites is a `const` int literal but the method return type is not `const`.

- [ ] **Step 1: Write failing test**

First, read the existing test file to see what's already covered:
```
flutter test test/utils/network_links_test.dart -v
```

Add to `test/utils/network_links_test.dart` (inside the existing `main()`):

```dart
test('getEasScanDomain returns domain for known chain', () {
  final domain = NetworkLinks.getEasScanDomain(11155111); // Sepolia
  expect(domain, 'https://sepolia.easscan.org');
});

test('getEasScanDomain returns null for unknown chain', () {
  final domain = NetworkLinks.getEasScanDomain(999);
  expect(domain, isNull);
});
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/utils/network_links_test.dart -v
```
Expected: FAIL — `getEasScanDomain` is not defined.

- [ ] **Step 3: Add method to `NetworkLinks`**

In `lib/utils/network_links.dart`, add after `getEasScanSchemaUrl`:

```dart
/// Returns the raw EAS Scan base domain for a chain, or null if unsupported.
/// Used to construct GraphQL endpoints: '${getEasScanDomain(chainId)}/graphql'.
static String? getEasScanDomain(int chainId) => _easScanDomains[chainId];
```

- [ ] **Step 4: Run tests**

```
flutter test test/utils/network_links_test.dart -v
```
Expected: PASS.

- [ ] **Step 5: Run full suite**

```
flutter test
```
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/utils/network_links.dart test/utils/network_links_test.dart
git commit -m "feat: add getEasScanDomain helper to NetworkLinks"
```

---

## Task 4: EAS Scan GraphQL Query

**Files:**
- Create: `lib/protocol/eas_scan_service.dart`
- Create: `test/protocol/eas_scan_service_test.dart`

### Key Details

Isolate the EAS Scan query into its own lightweight service — separating HTTP concerns from `AttestationService`. This class accepts an `http.Client` for testability.

> **Important — MockClient availability:** `http/testing.dart`'s `MockClient` is **not** available in `http ^1.x`. Use `mocktail` (already in `dev_dependencies`) with a stubbed `http.Client` instead.

```dart
// lib/protocol/eas_scan_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class RegisteredSchema {
  final String id;     // The schema UID (0x-prefixed)
  final String schema; // EAS schema string e.g. "uint256 eventTimestamp,string memo"
  final int index;

  const RegisteredSchema({required this.id, required this.schema, required this.index});
}

class EasScanService {
  final http.Client _client;
  final String graphqlEndpoint; // e.g. 'https://sepolia.easscan.org/graphql'

  EasScanService({required this.graphqlEndpoint, http.Client? client})
      : _client = client ?? http.Client();

  /// Returns all schemas created by [creatorAddress] on this chain.
  Future<List<RegisteredSchema>> queryUserSchemas(String creatorAddress) async {
    const query = r'''
      query Schemas($where: SchemaWhereInput) {
        schemas(where: $where, orderBy: [{index: desc}]) {
          id
          schema
          index
        }
      }
    ''';
    final variables = {
      'where': {
        'creator': {'equals': creatorAddress}
      }
    };
    final response = await _client.post(
      Uri.parse(graphqlEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query, 'variables': variables}),
    );
    if (response.statusCode != 200) {
      throw Exception('EAS Scan query failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data.containsKey('errors')) {
      throw Exception('GraphQL error: ${data['errors']}');
    }
    final schemas = (data['data']['schemas'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return schemas.map((s) => RegisteredSchema(
      id: s['id'] as String,
      schema: s['schema'] as String,
      index: s['index'] as int,
    )).toList();
  }
}
```

> **Note on the GraphQL query string:** Use a raw string literal (`r'''...'''`) to avoid escaping `$where` — otherwise `$where` is interpreted as Dart string interpolation.

- [ ] **Step 1: Write failing test using `mocktail`**

```dart
// test/protocol/eas_scan_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:location_protocol_flutter_app/protocol/eas_scan_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://fallback.example.com'));
  });

  setUp(() {
    mockClient = MockHttpClient();
  });

  group('EasScanService', () {
    test('queryUserSchemas returns parsed schemas on success', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'data': {
                'schemas': [
                  {'id': '0xabc', 'schema': 'string memo', 'index': 42},
                ],
              },
            }),
            200,
          ));

      final service = EasScanService(
        graphqlEndpoint: 'https://sepolia.easscan.org/graphql',
        client: mockClient,
      );

      final results = await service.queryUserSchemas('0xDeadBeef');
      expect(results.length, 1);
      expect(results.first.id, '0xabc');
      expect(results.first.schema, 'string memo');
      expect(results.first.index, 42);
    });

    test('queryUserSchemas throws on non-200 response', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Error', 500));

      final service = EasScanService(
        graphqlEndpoint: 'https://sepolia.easscan.org/graphql',
        client: mockClient,
      );
      expect(
        () => service.queryUserSchemas('0xDeadBeef'),
        throwsException,
      );
    });

    test('queryUserSchemas throws on GraphQL errors field', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'errors': [{'message': 'bad query'}]}),
            200,
          ));

      final service = EasScanService(
        graphqlEndpoint: 'https://sepolia.easscan.org/graphql',
        client: mockClient,
      );
      expect(
        () => service.queryUserSchemas('0xDeadBeef'),
        throwsException,
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
flutter test test/protocol/eas_scan_service_test.dart -v
```
Expected: FAIL — `EasScanService` not defined.

- [ ] **Step 3: Create `lib/protocol/eas_scan_service.dart`** with the implementation above.

- [ ] **Step 4: Run tests**

```
flutter test test/protocol/eas_scan_service_test.dart -v
```
Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/protocol/eas_scan_service.dart test/protocol/eas_scan_service_test.dart
git commit -m "feat: add EasScanService for GraphQL schema queries"
```

---

## Task 5: AttestationService Refactor

**Files:**
- Modify: `lib/protocol/attestation_service.dart`
- Modify: `test/protocol/attestation_service_test.dart`

### Key Details

Three changes to `AttestationService`:

**A) Add `isSchemaUidRegistered(String uid)`** — a generalized version of `isSchemaRegistered()` that accepts any UID. The existing `isSchemaRegistered()` can delegate to this.

**B) Add `signOffchainWithData(schema, lat, lng, userData)`** — a new method that accepts an explicit `userData` map, needed by the dynamic signing screens. The original `signOffchain(lat, lng, memo)` is **preserved** for backward compatibility with existing tests (it internally builds userData from the default fields).

**C) Add `buildAttestCallDataWithUserData(schema, lat, lng, userData)`** — equivalent for onchain path.

**D) Make `buildRegisterSchemaCallData` accept an explicit `SchemaDefinition`** — change signature from `buildRegisterSchemaCallData()` to `buildRegisterSchemaCallData(SchemaDefinition schema)`. Update all call sites.

> **Important:** Do NOT change `signOffchain`, `buildAttestCallData` signatures in a way that breaks existing tests. Only add new methods. This avoids a cascading refactor across all existing tests.

```dart
// New methods to add to AttestationService:

/// Generalized registration check — works for any schema UID.
Future<bool> isSchemaUidRegistered(String uid) async {
  final normalizedUid = uid.toLowerCase().startsWith('0x')
      ? uid.toLowerCase()
      : '0x${uid.toLowerCase()}';
  final record = await getSchemaRecord(normalizedUid);
  if (record == null || record.length < 66) return false;
  String returnedUid;
  if (record.length >= 130 && record.startsWith('0x0000000000000000000000000000000000000000000000000000000000000020')) {
    returnedUid = '0x${record.substring(66, 130)}'.toLowerCase();
  } else {
    returnedUid = record.substring(0, 66).toLowerCase();
  }
  return returnedUid == normalizedUid;
}

/// Original isSchemaRegistered now delegates to the generalized version.
Future<bool> isSchemaRegistered() => isSchemaUidRegistered(AppSchema.schemaUID);

/// Signs an offchain attestation with an explicit userData map.
/// Use this for dynamic schemas where userData is built from user inputs.
Future<SignedOffchainAttestation> signOffchainWithData({
  required SchemaDefinition schema,
  required double lat,
  required double lng,
  required Map<String, dynamic> userData,
}) {
  final lpPayload = AppSchema.buildLPPayload(lat: lat, lng: lng);
  return _offchainSigner.signOffchainAttestation(
    schema: schema,
    lpPayload: lpPayload,
    userData: userData,
  );
}

/// Builds onchain attest calldata with an explicit userData map.
/// Use this for dynamic schemas where userData is built from user inputs.
Uint8List buildAttestCallDataWithUserData({
  required SchemaDefinition schema,
  required double lat,
  required double lng,
  required Map<String, dynamic> userData,
}) {
  return EASClient.buildAttestCallData(
    schema: schema,
    lpPayload: AppSchema.buildLPPayload(lat: lat, lng: lng),
    userData: userData,
  );
}

/// Builds calldata for schema registration using a provided SchemaDefinition.
Uint8List buildRegisterSchemaCallData([SchemaDefinition? schema]) {
  return SchemaRegistryClient.buildRegisterCallData(schema ?? AppSchema.definition);
}
```

> **Note:** `buildRegisterSchemaCallData` uses an optional positional parameter with `AppSchema.definition` as default. This preserves backward compatibility with the existing test `service.buildRegisterSchemaCallData()`.

- [ ] **Step 1: Write failing tests for new methods**

Add to `test/protocol/attestation_service_test.dart` (new group):

```dart
group('AttestationService — new dynamic methods', () {
  test('isSchemaUidRegistered accepts any UID (returns false for test RPC)', () async {
    // Enough to test the method exists and doesn't throw with a fake RPC response
    final customService = AttestationService(
      signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
      chainId: 11155111,
      rpcUrl: 'https://unused.rpc',
      httpClient: FakeClient((_) async => http.Response(
        '{"jsonrpc":"2.0","id":1,"result":"0x0000000000000000000000000000000000000000000000000000000000000020"}',
        200,
      )),
    );
    final result = await customService.isSchemaUidRegistered('0x${'ab' * 32}');
    expect(result, isFalse); // UID won't match the fake response
  });

  test('signOffchainWithData returns a SignedOffchainAttestation', () async {
    final result = await service.signOffchainWithData(
      schema: AppSchema.definition,
      lat: 37.7749,
      lng: -122.4194,
      userData: AppSchema.buildUserData(memo: 'dynamic test'),
    );
    expect(result, isA<SignedOffchainAttestation>());
  });

  test('buildAttestCallDataWithUserData returns non-empty Uint8List', () {
    final callData = service.buildAttestCallDataWithUserData(
      schema: AppSchema.definition,
      lat: 37.7749,
      lng: -122.4194,
      userData: AppSchema.buildUserData(memo: 'dynamic test'),
    );
    expect(callData, isA<Uint8List>());
    expect(callData.isNotEmpty, isTrue);
  });

  test('buildRegisterSchemaCallData accepts explicit schema', () {
    final customSchema = SchemaDefinition(
      fields: [const SchemaField(type: 'string', name: 'test')],
    );
    final callData = service.buildRegisterSchemaCallData(customSchema);
    expect(callData, isA<Uint8List>());
    expect(callData.isNotEmpty, isTrue);
  });

  test('buildRegisterSchemaCallData uses default schema when called with no args', () {
    final callData = service.buildRegisterSchemaCallData();
    expect(callData, isA<Uint8List>());
    expect(callData.isNotEmpty, isTrue);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```
flutter test test/protocol/attestation_service_test.dart -v
```
Expected: FAIL on the new group tests.

- [ ] **Step 3: Add the new methods to `lib/protocol/attestation_service.dart`** as shown above. Replace `isSchemaRegistered()` with the delegating version.

- [ ] **Step 4: Run all tests**

```
flutter test
```
Expected: All tests PASS. Existing tests must remain green; no signatures were changed.

- [ ] **Step 5: Commit**

```bash
git add lib/protocol/attestation_service.dart test/protocol/attestation_service_test.dart
git commit -m "feat: add isSchemaUidRegistered, signOffchainWithData, buildAttestCallDataWithUserData to AttestationService"
```

---

## Task 6: Schema Manager Screen

**Files:**
- Create: `lib/screens/schema_manager_screen.dart`
- Create: `test/screens/schema_manager_screen_test.dart`
- Delete: `lib/screens/register_schema_screen.dart` (at end of this task)

### Key Details

`SchemaManagerScreen` is the consolidation of field CRUD and schema registration. It reads `SchemaProvider` via `context.watch<SchemaProvider>()`.

**Parsing registered schema strings from EAS Scan:**

```dart
static const _lpBaseFieldNames = {'lp_version', 'srs', 'location_type', 'location'};

List<SchemaField> _parseSchemaString(String schemaString) {
  return schemaString
      .split(',')
      .map((part) => part.trim().split(' '))
      .where((parts) => parts.length == 2)
      .map((parts) => SchemaField(type: parts[0], name: parts[1]))
      .where((f) => !_lpBaseFieldNames.contains(f.name))
      .toList();
}
```

**Registration check** uses `AttestationService.isSchemaUidRegistered(uid)` where `uid` comes from `context.read<SchemaProvider>().schemaUID`. This runs in `initState` when `service != null`.

**Registration action** calls `buildRegisterSchemaCallData(provider.definition)`, builds a tx, and submits via `AppWalletProvider.sendTransaction`. This is the same flow as the old `RegisterSchemaScreen._register()`.

**EAS Scan dropdown** is populated in `initState` by calling `EasScanService.queryUserSchemas(walletAddress)`. If the wallet address is null (private key mode or disconnected), skip the fetch and show a disabled/empty dropdown. When a schema is selected, call `schemaProvider.setSchema(_parseSchemaString(selected.schema))`.

**Supported add-field types:** `string`, `uint256`, `address`, `bool`, `bytes`, `bytes32`, `string[]`, `bytes[]`

**Schema UID re-check on changes:** When `SchemaProvider` notifies (field added/removed/reset), if `service != null`, reset `_isRegistered = false` and call `_checkRegistrationStatus()` again. Do this inside the `build` method by comparing the current UID to a cached `_lastCheckedUID`.

- [ ] **Step 1: Write widget smoke tests**

```dart
// test/screens/schema_manager_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';
import 'package:location_protocol_flutter_app/providers/schema_provider.dart';
import 'package:location_protocol_flutter_app/screens/schema_manager_screen.dart';
import 'package:location_protocol_flutter_app/settings/settings_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<Widget> buildSubject({SchemaProvider? schemaProvider}) async {
    final settingsService = await SettingsService.create();
    // AppWalletProvider only requires settingsService — other params are optional
    final walletProvider = AppWalletProvider(settingsService: settingsService);
    final provider = schemaProvider ?? SchemaProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SchemaProvider>.value(value: provider),
        ChangeNotifierProvider<AppWalletProvider>.value(value: walletProvider),
      ],
      child: const MaterialApp(home: SchemaManagerScreen()),
    );
  }

  testWidgets('renders field table with default user fields', (tester) async {
    await tester.pumpWidget(await buildSubject());
    await tester.pump();
    expect(find.text('eventTimestamp'), findsOneWidget);
    expect(find.text('memo'), findsOneWidget);
  });

  testWidgets('shows Active Schema UID section', (tester) async {
    await tester.pumpWidget(await buildSubject());
    await tester.pump();
    expect(find.text('Active Schema UID'), findsOneWidget);
  });

  testWidgets('tapping Reset to Default restores all 6 default fields', (tester) async {
    final schemaProvider = SchemaProvider();
    schemaProvider.removeField('memo');
    expect(schemaProvider.userFields.any((f) => f.name == 'memo'), isFalse);

    await tester.pumpWidget(await buildSubject(schemaProvider: schemaProvider));
    await tester.pump();

    await tester.tap(find.text('Reset to Default'));
    await tester.pumpAndSettle();
    expect(schemaProvider.userFields.any((f) => f.name == 'memo'), isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```
flutter test test/screens/schema_manager_screen_test.dart -v
```
Expected: FAIL — `SchemaManagerScreen` not defined.

- [ ] **Step 3: Create `lib/screens/schema_manager_screen.dart`**

Full skeleton (all methods must be implemented, not just stubbed):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../protocol/attestation_service.dart';
import '../protocol/eas_scan_service.dart';
import '../providers/app_wallet_provider.dart';
import '../providers/schema_provider.dart';
import '../utils/network_links.dart';
import 'package:location_protocol/location_protocol.dart';

class SchemaManagerScreen extends StatefulWidget {
  /// When null, the registration section is hidden (field management only).
  final AttestationService? service;
  const SchemaManagerScreen({super.key, this.service});

  @override
  State<SchemaManagerScreen> createState() => _SchemaManagerScreenState();
}

class _SchemaManagerScreenState extends State<SchemaManagerScreen> {
  // Dropdown state
  List<RegisteredSchema> _registeredSchemas = [];
  RegisteredSchema? _selectedSchema;
  bool _loadingSchemas = false;
  String? _schemasError;

  // Add-field state
  String _newFieldType = 'string';
  final _newFieldNameController = TextEditingController();

  // Registration state
  bool _checkingRegistration = false;
  bool _isRegistered = false;
  bool _registering = false;
  String? _registrationError;
  String? _txHash;
  String? _lastCheckedUID; // track which UID we last checked

  static const _supportedTypes = [
    'string', 'uint256', 'address', 'bool', 'bytes', 'bytes32', 'string[]', 'bytes[]',
  ];

  static const _lpBaseFieldNames = {
    'lp_version', 'srs', 'location_type', 'location',
  };

  @override
  void initState() {
    super.initState();
    _loadRegisteredSchemas();
  }

  @override
  void dispose() {
    _newFieldNameController.dispose();
    super.dispose();
  }

  Future<void> _loadRegisteredSchemas() async {
    final walletProvider = context.read<AppWalletProvider>();
    final address = walletProvider.walletAddress;
    final chainId = widget.service?.chainId;
    final domain = chainId != null ? NetworkLinks.getEasScanDomain(chainId) : null;

    if (address == null || domain == null) return; // nothing to fetch

    setState(() { _loadingSchemas = true; _schemasError = null; });
    try {
      final service = EasScanService(graphqlEndpoint: '$domain/graphql');
      final schemas = await service.queryUserSchemas(address);
      if (mounted) setState(() => _registeredSchemas = schemas);
    } catch (e) {
      if (mounted) setState(() => _schemasError = e.toString());
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

  Future<void> _checkRegistrationStatus(String uid) async {
    if (widget.service == null) return;
    setState(() { _checkingRegistration = true; _registrationError = null; });
    try {
      final registered = await widget.service!.isSchemaUidRegistered(uid);
      if (mounted) setState(() { _isRegistered = registered; _lastCheckedUID = uid; });
    } catch (e) {
      if (mounted) setState(() => _registrationError = 'Status check: $e');
    } finally {
      if (mounted) setState(() => _checkingRegistration = false);
    }
  }

  Future<void> _register(SchemaProvider schemaProvider) async {
    setState(() { _registering = true; _txHash = null; _registrationError = null; });
    try {
      final callData = widget.service!.buildRegisterSchemaCallData(schemaProvider.definition);
      final txRequest = widget.service!.buildTxRequest(
        callData: callData,
        contractAddress: widget.service!.schemaRegistryAddress,
      );
      final txHash = await context.read<AppWalletProvider>().sendTransaction(
        txRequest,
        context: context,
      );
      if (txHash == null) throw Exception('Transaction cancelled or failed');
      if (mounted) setState(() => _txHash = txHash);
      // Poll and confirm
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 2));
        final receipt = await widget.service!.getTransactionReceipt(txHash);
        if (receipt != null) {
          await _checkRegistrationStatus(schemaProvider.schemaUID);
          break;
        }
      }
    } catch (e) {
      if (mounted) setState(() => _registrationError = e.toString());
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schemaProvider = context.watch<SchemaProvider>();
    final currentUID = schemaProvider.schemaUID;

    // When the UID changes (user edits fields), reset registration state
    if (_lastCheckedUID != null && _lastCheckedUID != currentUID) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() { _isRegistered = false; });
          _checkRegistrationStatus(currentUID);
        }
      });
    } else if (_lastCheckedUID == null && widget.service != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkRegistrationStatus(currentUID);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Schema Manager')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDropdownSection(schemaProvider),
            const SizedBox(height: 16),
            _buildUIDSection(schemaProvider),
            const SizedBox(height: 16),
            _buildFieldsTable(schemaProvider),
            const SizedBox(height: 16),
            _buildAddFieldRow(schemaProvider),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: schemaProvider.resetToDefault,
              child: const Text('Reset to Default'),
            ),
            if (widget.service != null) ...[
              const SizedBox(height: 16),
              _buildRegistrationSection(schemaProvider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSection(SchemaProvider schemaProvider) {
    // ... implement dropdown with _registeredSchemas
    // When selected: schemaProvider.setSchema(_parseSchemaString(schema.schema))
    return const SizedBox.shrink(); // placeholder; implement fully
  }

  Widget _buildUIDSection(SchemaProvider schemaProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Active Schema UID', style: TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: schemaProvider.schemaUID));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Schema UID copied')),
              );
            },
          ),
        ]),
        SelectableText(
          schemaProvider.schemaUID,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildFieldsTable(SchemaProvider schemaProvider) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Field')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Action')),
      ],
      rows: schemaProvider.userFields.map((field) => DataRow(
        cells: [
          DataCell(Text(field.name)),
          DataCell(Text(field.type)),
          DataCell(TextButton(
            onPressed: () => schemaProvider.removeField(field.name),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          )),
        ],
      )).toList(),
    );
  }

  Widget _buildAddFieldRow(SchemaProvider schemaProvider) {
    return Row(children: [
      DropdownButton<String>(
        value: _newFieldType,
        items: _supportedTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setState(() => _newFieldType = v!),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: _newFieldNameController,
          decoration: const InputDecoration(labelText: 'Field name', border: OutlineInputBorder()),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        icon: const Icon(Icons.add_circle),
        onPressed: () {
          final name = _newFieldNameController.text.trim();
          if (name.isEmpty) return;
          schemaProvider.addField(SchemaField(type: _newFieldType, name: name));
          _newFieldNameController.clear();
        },
      ),
    ]);
  }

  Widget _buildRegistrationSection(SchemaProvider schemaProvider) {
    final easUrl = NetworkLinks.getEasScanSchemaUrl(
      widget.service!.chainId,
      schemaProvider.schemaUID,
    );
    // ... implement full registration card (same as RegisterSchemaScreen)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isRegistered) ...[
          Card(
            color: Colors.blue.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                const Row(children: [
                  Icon(Icons.check_circle, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(child: Text('Schema already registered onchain.',
                    style: TextStyle(fontWeight: FontWeight.bold))),
                ]),
                if (easUrl != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('View at: $easUrl')),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View on EAS Scan'),
                  ),
                ],
              ]),
            ),
          ),
        ],
        FilledButton.icon(
          onPressed: (_registering || _checkingRegistration || _isRegistered)
              ? null
              : () => _register(schemaProvider),
          icon: _registering
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.cloud_upload),
          label: Text(_isRegistered ? 'Already Registered' : 'Register Schema Onchain'),
        ),
        if (_registrationError != null) ...[
          const SizedBox(height: 8),
          Text(_registrationError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Run widget tests**

```
flutter test test/screens/schema_manager_screen_test.dart -v
```
Expected: All 3 tests PASS.

- [ ] **Step 5: Delete `RegisterSchemaScreen`**

```powershell
Remove-Item lib/screens/register_schema_screen.dart
```

- [ ] **Step 6: Fix import errors**

```
flutter analyze
```
Fix any file still importing `register_schema_screen.dart` (will be `home_screen.dart`).

- [ ] **Step 7: Run full suite**

```
flutter test
```
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add SchemaManagerScreen; merge RegisterSchemaScreen"
```

---

## Task 7: Dynamic Fields in Signing Screens

**Files:**
- Modify: `lib/screens/sign_screen.dart`
- Modify: `lib/screens/onchain_attest_screen.dart`
- Modify: `test/screens/onchain_attest_screen_test.dart`

### Key Details

Both screens will dynamically render a `TextField` per `SchemaField` in `SchemaProvider.userFields`. Controllers are managed by tracking the **field count and names** (not list identity) in `didChangeDependencies`.

**Controller lifecycle — critical fix:** `provider.userFields` returns a *new* list instance on every call, so identity comparison (`!=`) always returns `true`. Instead, track field signatures:

```dart
List<TextEditingController> _fieldControllers = [];
String _lastKnownFieldSignature = '';

String _fieldSignature(List<SchemaField> fields) =>
    fields.map((f) => '${f.type}:${f.name}').join(',');

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final provider = context.watch<SchemaProvider>();
  final sig = _fieldSignature(provider.userFields);
  if (sig != _lastKnownFieldSignature) {
    for (final c in _fieldControllers) c.dispose();
    _fieldControllers = provider.userFields.map((_) => TextEditingController()).toList();
    _lastKnownFieldSignature = sig;
  }
}
```

**Lat/lng fields remain hardcoded** — they are LP base fields, not user fields.

**Build `userData` at submission:**

```dart
Map<String, dynamic> _buildUserData(SchemaProvider provider) {
  final data = <String, dynamic>{};
  for (int i = 0; i < provider.userFields.length; i++) {
    final field = provider.userFields[i];
    final text = _fieldControllers[i].text.trim();
    switch (field.type) {
      case 'uint256':
        data[field.name] = BigInt.tryParse(text) ?? BigInt.zero;
      case 'bool':
        data[field.name] = text.toLowerCase() == 'true';
      case 'string[]':
      case 'bytes[]':
      case 'address[]':
        data[field.name] = text.isEmpty ? <String>[] : text.split(',').map((s) => s.trim()).toList();
      default:
        data[field.name] = text;
    }
  }
  return data;
}
```

**Call `signOffchainWithData` / `buildAttestCallDataWithUserData`** (added in Task 5):

```dart
// SignScreen:
final userData = _buildUserData(provider);
final signed = await widget.service.signOffchainWithData(
  schema: provider.definition,
  lat: lat,
  lng: lng,
  userData: userData,
);

// OnchainAttestScreen:
final userData = _buildUserData(provider);
final callData = widget.service.buildAttestCallDataWithUserData(
  schema: provider.definition,
  lat: lat,
  lng: lng,
  userData: userData,
);
```

**dispose:** Call `dispose()` on all `_fieldControllers`.

- [ ] **Step 1: Update `onchain_attest_screen_test.dart`**

Add `SchemaProvider` to the provider list:

```dart
// In the test widget setup, add SchemaProvider:
MultiProvider(
  providers: [
    ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider()),
    ChangeNotifierProvider<AppWalletProvider>.value(value: walletProvider),
  ],
  child: MaterialApp(home: OnchainAttestScreen(service: service)),
)
```

Add `import 'package:location_protocol_flutter_app/providers/schema_provider.dart';` at the top.

- [ ] **Step 2: Run existing screen tests to see what breaks**

```
flutter test test/screens/onchain_attest_screen_test.dart -v
```
Note any failures.

- [ ] **Step 3: Refactor `SignScreen`**

Replace `_memoController` with `_fieldControllers` list + `didChangeDependencies`. Update `_sign()` to use `signOffchainWithData`.

- [ ] **Step 4: Refactor `OnchainAttestScreen`**

Same pattern: replace `_memoController` with `_fieldControllers`. Update `_submit()` to use `buildAttestCallDataWithUserData`.

- [ ] **Step 5: Run all tests**

```
flutter test
```
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/sign_screen.dart lib/screens/onchain_attest_screen.dart test/screens/onchain_attest_screen_test.dart
git commit -m "feat: dynamic field rendering in signing screens from SchemaProvider"
```

---

## Task 8: Main Setup and Navigation

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/home_screen.dart`

### Key Details

**`main.dart`:** `SchemaProvider.load()` is async, so load it in `_loadSettings()` alongside `SettingsService`. Add `SchemaProvider? _schemaProvider;` as a state field. Wait for both to complete before calling `setState`. Add `ChangeNotifierProvider<SchemaProvider>.value(value: _schemaProvider!)` to `MultiProvider`.

**`HomeScreen` — Navigation Placement (important):**

Schema Manager must be accessible in **offchain/private key mode** — not gated behind `canSendTransactions`. Add a new always-visible section "Schema" above onchain operations. The buttons:
- `_buildSchemaManagerButton(context, walletProvider)` — always shown when any connection type is active (or even no connection, for field design without registration).
- Remove `_buildRegisterSchemaButton`.

When no wallet can send transactions, pass `service: null` to `SchemaManagerScreen` — the registration section will be hidden.
When a wallet CAN send transactions, pass a full `AttestationService`.

```dart
// In HomeScreen build:
// Always show:
_SectionHeader('Schema'),
_buildSchemaManagerButton(context, walletProvider),
const SizedBox(height: 24),

// Onchain section (canSendTransactions only):
if (walletProvider.canSendTransactions) ...[
  _SectionHeader('Onchain Operations'),
  _buildOnchainAttestButton(context, walletProvider),
  const SizedBox(height: 8),
  _buildTimestampButton(context, walletProvider), // register moved to Schema Manager
],
```

```dart
Widget _buildSchemaManagerButton(BuildContext context, AppWalletProvider walletProvider) {
  return _ActionButton(
    icon: Icons.tune,
    label: 'Schema Manager',
    onPressed: () {
      final signer = walletProvider.walletAddress != null
          ? walletProvider.getSigner(context, widget.runtimeNetworkConfig.selectedChainId)
          : null;
      final isSponsored = dotenv.env['GAS_SPONSORSHIP']?.toLowerCase() == 'true';
      final service = signer != null
          ? AttestationService(
              signer: signer,
              chainId: widget.runtimeNetworkConfig.selectedChainId,
              rpcUrl: widget.runtimeNetworkConfig.rpcUrl,
              sponsorGas: isSponsored,
            )
          : null;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SchemaManagerScreen(service: service)),
      );
    },
  );
}
```

- [ ] **Step 1: Update `main.dart`**

Add `SchemaProvider? _schemaProvider;` field. In `_loadSettings`, await `SchemaProvider.load()` alongside `SettingsService.create()`. Use `Future.wait` to run them concurrently:

```dart
final results = await Future.wait([
  SettingsService.create(),
  SchemaProvider.load(),
]);
final settingsService = results[0] as SettingsService;
final schemaProvider = results[1] as SchemaProvider;
```

Add `ChangeNotifierProvider<SchemaProvider>.value(value: _schemaProvider!)` to `MultiProvider`.

- [ ] **Step 2: Update `HomeScreen`**

Add `schema_manager_screen.dart` import. Remove `register_schema_screen.dart` import. Implement `_buildSchemaManagerButton`. Update the section layout as described above.

- [ ] **Step 3: Run home screen tests**

```
flutter test test/screens/home_screen_auth_test.dart -v
```
Fix any failures from the nav changes.

- [ ] **Step 4: Run full suite**

```
flutter test
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/screens/home_screen.dart
git commit -m "feat: provide SchemaProvider in widget tree; Schema Manager always accessible"
```

---

## Task 9: Cleanup and Memory

**Files:**
- Modify: `.ai/memory/semantic.md`
- Modify: `.ai/memory/episodic.md`

- [ ] **Step 1: Run full test suite**

```
flutter test --reporter=expanded
```
Expected: All tests PASS, no warnings.

- [ ] **Step 2: Run static analysis**

```
flutter analyze
```
Expected: No issues.

- [ ] **Step 3: Update `.ai/memory/semantic.md`**

Add:
- `SchemaProvider` is the global source of truth for the active schema; signing screens and `SchemaManagerScreen` read from it.
- `EasScanService` handles EAS Scan GraphQL queries via `http.Client` injection; isolated from `AttestationService`.
- `SchemaManagerScreen` consolidates field CRUD and schema registration; replaces `RegisterSchemaScreen`.
- `AttestationService.isSchemaUidRegistered(uid)` is the generalized registration check; `isSchemaRegistered()` delegates to it using `AppSchema.schemaUID`.
- `signOffchainWithData` / `buildAttestCallDataWithUserData` are the dynamic-schema signing paths; the original `signOffchain` / `buildAttestCallData` are preserved for test backward compatibility.

- [ ] **Step 4: Update `.ai/memory/episodic.md`**

```
[ID: SCHEMA_MANAGER] -> Follows [AppWalletProvider refactor].
Introduced SchemaProvider (ChangeNotifier) with SharedPreferences persistence.
Added EasScanService for GraphQL queries. SchemaManagerScreen replaces RegisterSchemaScreen.
Signing screens now dynamically render user fields. Schema Manager accessible in all wallet modes.
```

- [ ] **Step 5: Create walkthrough**

Create `docs/walkthroughs/2026-03-24-schema-manager-walkthrough.md` documenting what was built and how to manually verify.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore: update agent memory and add schema manager walkthrough"
```

---

## Verification Plan

### Automated Tests

```
flutter test --reporter=expanded
```
All tests PASS with zero warnings.

```
flutter analyze
```
Zero issues.

### Manual Verification

1. **Start the app** — `flutter run -d <device>` (web, Android, iOS, or desktop)
2. **Without connecting a wallet**, navigate to **Schema Manager** — confirm it opens and shows the default 6 fields and a Schema UID.
3. **Remove a field** (e.g., `memo`). Confirm the UID updates immediately.
4. **Add a new field** (type: `string`, name: `testField`). Confirm it appears in the table and UID updates.
5. **Click "Reset to Default"** — confirm all 6 default fields are restored.
6. **Connect an external or Privy wallet**, return to Schema Manager — confirm the "Select Registered Schema" dropdown attempts to fetch from EAS Scan.
7. **Select a registered schema** from the dropdown — confirm LP base fields are stripped and user fields are populated.
8. **Register Schema Onchain** (wallet with gas required) — confirm button changes to "Already Registered" and the EAS Scan link appears.
9. **Navigate to Sign Attestation (Offchain)** — confirm dynamic fields from the active schema appear as inputs (not just a hardcoded "Memo" field).
10. **Navigate to Attest Onchain** — confirm the same dynamic fields appear as inputs.
