# Schema Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a `SchemaProvider` for dynamic active-schema management, build a standalone `SchemaManagerScreen` that replaces `RegisterSchemaScreen`, and refactor signing screens to dynamically render user fields from the active schema.

**Architecture:** A `SchemaProvider` (`ChangeNotifier`) serves as the global source of truth for the active schema definition, computing the UID reactively. A new `SchemaManagerScreen` handles field CRUD, EAS Scan dropdown, and onchain schema registration. Signing screens (`SignScreen`, `OnchainAttestScreen`) will read from `SchemaProvider` to generate dynamic input fields and build `userData` at submission time.

**Tech Stack:** Flutter / Dart, `provider ^6.x`, `shared_preferences ^2.x`, `http ^1.x`, `location_protocol` (git), `flutter_test`, `mocktail`

---

## Table of Contents

| Task | Component | Description |
|------|-----------|-------------|
| [Task 1](#task-1-schema-provider) | `SchemaProvider` | Core state manager — add, remove, set, reset schema fields |
| [Task 2](#task-2-schema-provider-persistence) | `SchemaProvider` (persistence) | Persist/restore active schema via `SharedPreferences` |
| [Task 3](#task-3-networklinks-helper) | `NetworkLinks` | Add `getEasScanDomain(chainId)` helper |
| [Task 4](#task-4-eas-scan-graphql-query) | `AttestationService` | `queryUserSchemas(address)` via EAS Scan GraphQL |
| [Task 5](#task-5-schema-manager-screen) | `SchemaManagerScreen` | New standalone UI screen |
| [Task 6](#task-6-register-schema-migration) | `SchemaManagerScreen` | Merge `RegisterSchemaScreen` logic into Schema Manager |
| [Task 7](#task-7-attestation-service-refactor) | `AttestationService` | Accept dynamic `SchemaDefinition` instead of static `AppSchema` |
| [Task 8](#task-8-dynamic-fields-in-signing-screens) | `SignScreen` / `OnchainAttestScreen` | Dynamically render user fields from `SchemaProvider` |
| [Task 9](#task-9-main-setup-and-navigation) | `main.dart` / `HomeScreen` | Provide `SchemaProvider` in widget tree; update nav |
| [Task 10](#task-10-cleanup-and-memory) | Cleanup | Delete `RegisterSchemaScreen`, update memory |

---

## Task 1: Schema Provider

**Files:**
- Create: `lib/providers/schema_provider.dart`
- Create: `test/providers/schema_provider_test.dart`

### Key Details

`SchemaProvider` wraps a mutable list of **user** `SchemaField`s. It never exposes or modifies the LP base fields — those are managed by the `location_protocol` library automatically via `SchemaDefinition`. The `schemaUID` is computed on every mutation.

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
Expected: All 7 tests PASS.

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

Serialize/deserialize `List<SchemaField>` as JSON via `SharedPreferences`. The schema is stored as a list of `{"type": "...", "name": "..."}` objects. Persistence is on factory construction (`SchemaProvider.load()`) and on every mutation.

The field list JSON key is `schema_provider_fields`.

- [ ] **Step 1: Write failing persistence tests**

Add these tests to `test/providers/schema_provider_test.dart`, inside the existing `group`:

```dart
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
});
```

Add `import 'package:shared_preferences/shared_preferences.dart';` to the test file.

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/providers/schema_provider_test.dart -v
```
Expected: FAIL — `SchemaProvider.load` not found.

- [ ] **Step 3: Extend `SchemaProvider` with persistence**

Add to `lib/providers/schema_provider.dart`:

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Inside SchemaProvider class:
static const String _prefsKey = 'schema_provider_fields';

/// Factory constructor that loads the persisted schema from SharedPreferences.
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
    return SchemaProvider(); // fallback to default on corrupt data
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

Also call `save()` (fire-and-forget, `unawaited`) in `addField`, `removeField`, `setSchema`, and `resetToDefault` after `notifyListeners()`:

```dart
void addField(SchemaField field) {
  _userFields.add(field);
  _rebuild();
  notifyListeners();
  unawaited(save()); // import 'dart:async' for unawaited
}
```

- [ ] **Step 4: Run tests to verify they pass**

```
flutter test test/providers/schema_provider_test.dart -v
```
Expected: All tests PASS.

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

Add a `getEasScanDomain(int chainId)` that returns the raw domain string (or `null`) — this will be used by `AttestationService` to construct the GraphQL endpoint.

- [ ] **Step 1: Write failing test**

Add to `test/utils/network_links_test.dart`:

```dart
test('getEasScanDomain returns domain for known chain', () {
  const domain = NetworkLinks.getEasScanDomain(11155111); // Sepolia
  expect(domain, 'https://sepolia.easscan.org');
});

test('getEasScanDomain returns null for unknown chain', () {
  const domain = NetworkLinks.getEasScanDomain(999);
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
static String? getEasScanDomain(int chainId) => _easScanDomains[chainId];
```

- [ ] **Step 4: Run tests**

```
flutter test test/utils/network_links_test.dart -v
```
Expected: PASS.

- [ ] **Step 5: Commit**

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

Isolate the EAS Scan query into its own lightweight service to keep concerns separate from `AttestationService`. This class takes an `http.Client` for testability.

```dart
// lib/protocol/eas_scan_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class RegisteredSchema {
  final String id;    // The schema UID (0x-prefixed)
  final String schema; // EAS schema string
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
    const query = '''
      query Schemas(\$where: SchemaWhereInput) {
        schemas(where: \$where, orderBy: [{index: desc}]) {
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

- [ ] **Step 1: Write failing test**

```dart
// test/protocol/eas_scan_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:location_protocol_flutter_app/protocol/eas_scan_service.dart';

void main() {
  group('EasScanService', () {
    test('queryUserSchemas returns parsed schemas on success', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': {
              'schemas': [
                {'id': '0xabc', 'schema': 'string memo', 'index': 42},
              ],
            },
          }),
          200,
        );
      });

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
      final mockClient = MockClient((_) async => http.Response('Error', 500));
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

Note: `http/testing.dart` is part of `package:http`. No extra dependencies needed.

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
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/protocol/eas_scan_service.dart test/protocol/eas_scan_service_test.dart
git commit -m "feat: add EasScanService for GraphQL schema queries"
```

---

## Task 5: Schema Manager Screen (Fields UI)

**Files:**
- Create: `lib/screens/schema_manager_screen.dart`
- Create: `test/screens/schema_manager_screen_test.dart`

### Key Details

The screen reads from `SchemaProvider` (via `context.watch`) and writes back via the provider's methods. The EAS Scan dropdown is populated by calling `EasScanService` in `initState` with the connected wallet address from `AppWalletProvider`.

When the user selects a schema from the dropdown, we parse the EAS schema string into `SchemaField` list and call `provider.setSchema(...)`. The LP base field names (`lp_version`, `srs`, `location_type`, `location`) must be stripped from parsed fields, since they are managed by the library.

**Parsing a registered schema string:**
A registered EAS schema string looks like: `"string lp_version,string srs,string location_type,string location,uint256 eventTimestamp,string memo"`.
Strip LP base fields by name after parsing.

```dart
// Helper to parse EAS schema string (in schema_manager_screen.dart or SchemaProvider)
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

The "Add Field" row uses a `DropdownButton` for the type (Supported: `string`, `uint256`, `address`, `bool`, `bytes`, `bytes32`, `string[]`, `bytes[]`) and a validated `TextField` for name.

- [ ] **Step 1: Write widget smoke test**

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

  Future<Widget> _buildSubject(WidgetTester tester) async {
    final settingsService = await SettingsService.create();
    final walletProvider = AppWalletProvider(settingsService: settingsService);
    final schemaProvider = SchemaProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SchemaProvider>.value(value: schemaProvider),
        ChangeNotifierProvider<AppWalletProvider>.value(value: walletProvider),
      ],
      child: const MaterialApp(home: SchemaManagerScreen()),
    );
  }

  testWidgets('renders field table with default user fields', (tester) async {
    await tester.pumpWidget(await _buildSubject(tester));
    await tester.pump();
    // Default has 6 user fields; confirm at least one renders
    expect(find.text('eventTimestamp'), findsOneWidget);
    expect(find.text('memo'), findsOneWidget);
  });

  testWidgets('shows Schema UID section', (tester) async {
    await tester.pumpWidget(await _buildSubject(tester));
    await tester.pump();
    expect(find.text('Active Schema UID'), findsOneWidget);
  });

  testWidgets('tapping Reset to Default calls resetToDefault', (tester) async {
    final schemaProvider = SchemaProvider();
    schemaProvider.removeField('memo');
    expect(schemaProvider.userFields.any((f) => f.name == 'memo'), isFalse);

    final settingsService = await SettingsService.create();
    final walletProvider = AppWalletProvider(settingsService: settingsService);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SchemaProvider>.value(value: schemaProvider),
        ChangeNotifierProvider<AppWalletProvider>.value(value: walletProvider),
      ],
      child: const MaterialApp(home: SchemaManagerScreen()),
    ));
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

Key structure (implement the full widget):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/schema_provider.dart';
import '../providers/app_wallet_provider.dart';
import '../protocol/attestation_service.dart';
import '../protocol/eas_scan_service.dart';
import '../utils/network_links.dart';

class SchemaManagerScreen extends StatefulWidget {
  final AttestationService? service; // null = registration disabled
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

  // Add field state
  String _newFieldType = 'string';
  final _newFieldNameController = TextEditingController();

  // Registration state (only relevant when service != null)
  bool _checkingRegistration = false;
  bool _isRegistered = false;
  bool _registering = false;
  String? _registrationError;
  String? _txHash;

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
    if (widget.service != null) _checkRegistrationStatus();
  }

  @override
  void dispose() {
    _newFieldNameController.dispose();
    super.dispose();
  }
  
  // ... (fetchSchemas, parseSchemaString, _checkRegistrationStatus, _register, build)
}
```

The `build` method renders:
1. A section title "Select Registered Schema" with a `DropdownButton<RegisteredSchema>`.
2. A "Active Schema UID" section with a `SelectableText` and copy `IconButton`.
3. A `DataTable` with columns "Field" and "Type", one row per `schemaProvider.userFields`, each with a "Remove" `TextButton`.
4. An "Add Field" row with a `DropdownButton` for type and a `TextField` for name, plus an add `IconButton`.
5. A "Reset to Default" `OutlinedButton`.
6. If `service != null`: a "Register Schema Onchain" `FilledButton` (or "Already Registered" disabled state + EAS Scan link).

- [ ] **Step 4: Run tests**

```
flutter test test/screens/schema_manager_screen_test.dart -v
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/schema_manager_screen.dart test/screens/schema_manager_screen_test.dart
git commit -m "feat: add SchemaManagerScreen with field table and dropdown"
```

---

## Task 6: Register Schema Migration

**Files:**
- Modify: `lib/screens/schema_manager_screen.dart` (already scaffolded above)
- Delete: `lib/screens/register_schema_screen.dart`

### Key Details

The `SchemaManagerScreen` accepts an optional `AttestationService? service`. When `service` is non-null, it shows the registration card at the bottom. The registration flow is identical to the existing `RegisterSchemaScreen` but reads schema data from `SchemaProvider` instead of static `AppSchema`.

`_checkRegistrationStatus` calls `widget.service!.isSchemaRegistered()` but must pass the **current** `SchemaDefinition` UID from the provider, not the static `AppSchema.schemaUID`. This requires extending `AttestationService` slightly — done in Task 7.

For now, use the provider's UID for the EAS Scan link and display.

- [ ] **Step 1: Extend `_SchemaManagerScreenState` with registration logic**

Add to the state class:

```dart
Future<void> _checkRegistrationStatus() async {
  if (widget.service == null) return;
  setState(() { _checkingRegistration = true; _registrationError = null; });
  try {
    final schemaProvider = context.read<SchemaProvider>();
    final uid = schemaProvider.schemaUID;
    final record = await widget.service!.getSchemaRecord(uid);
    final registered = record != null && record.length >= 66 && !record.startsWith('0x0000');
    if (mounted) setState(() => _isRegistered = registered);
  } catch (e) {
    if (mounted) setState(() => _registrationError = 'Status check: $e');
  } finally {
    if (mounted) setState(() => _checkingRegistration = false);
  }
}

Future<void> _register() async {
  // Same implementation as RegisterSchemaScreen._register()
  // but uses SchemaProvider's definition from context.read<SchemaProvider>()
}
```

- [ ] **Step 2: Run widget smoke test**

```
flutter test test/screens/schema_manager_screen_test.dart -v
```
Expected: Still PASS.

- [ ] **Step 3: Delete `lib/screens/register_schema_screen.dart`**

```bash
Remove-Item lib/screens/register_schema_screen.dart
```

- [ ] **Step 4: Fix any import errors from the deletion**

Run `flutter analyze` and fix any files importing `register_schema_screen.dart`.

```
flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: merge RegisterSchemaScreen into SchemaManagerScreen"
```

---

## Task 7: AttestationService Refactor

**Files:**
- Modify: `lib/protocol/attestation_service.dart`
- Modify: `lib/protocol/schema_config.dart`
- Modify: `test/protocol/attestation_service_test.dart`

### Key Details

`AttestationService` currently hardcodes `AppSchema.definition` in `signOffchain`, `buildAttestCallData`, and `buildRegisterSchemaCallData`. We need to accept a `SchemaDefinition` parameter on each of these methods. `AppSchema` becomes a pure static helper (default field list + `buildLPPayload` + `buildUserData`) — the static `definition` and `schemaUID` remain for backwards compatibility with existing tests.

**Change signatures:**

```dart
// Before
Future<SignedOffchainAttestation> signOffchain({required double lat, required double lng, required String memo, BigInt? eventTimestamp});

// After
Future<SignedOffchainAttestation> signOffchain({required SchemaDefinition schema, required double lat, required double lng, required String memo, BigInt? eventTimestamp});
```

Similarly for `buildAttestCallData` and `buildRegisterSchemaCallData`.

- [ ] **Step 1: Update `attestation_service_test.dart`** to pass `schema: AppSchema.definition` to updated methods.

Run existing tests first to see what breaks:
```
flutter test test/protocol/attestation_service_test.dart -v
```

- [ ] **Step 2: Update method signatures in `lib/protocol/attestation_service.dart`**

```dart
Future<SignedOffchainAttestation> signOffchain({
  required SchemaDefinition schema,
  required double lat,
  required double lng,
  required String memo,
  BigInt? eventTimestamp,
}) {
  final lpPayload = AppSchema.buildLPPayload(lat: lat, lng: lng);
  final userData = AppSchema.buildUserData(memo: memo, eventTimestamp: eventTimestamp);
  return _offchainSigner.signOffchainAttestation(
    schema: schema,
    lpPayload: lpPayload,
    userData: userData,
  );
}

Uint8List buildAttestCallData({
  required SchemaDefinition schema,
  required double lat,
  required double lng,
  required String memo,
  BigInt? eventTimestamp,
}) {
  return EASClient.buildAttestCallData(
    schema: schema,
    lpPayload: AppSchema.buildLPPayload(lat: lat, lng: lng),
    userData: AppSchema.buildUserData(memo: memo, eventTimestamp: eventTimestamp),
  );
}

Uint8List buildRegisterSchemaCallData(SchemaDefinition schema) {
  return SchemaRegistryClient.buildRegisterCallData(schema);
}
```

> **Note on `buildUserData`:** The existing `AppSchema.buildUserData` is hardcoded to the 6 default fields. For Task 8 (dynamic signing screens), the user data will be built dynamically from input values — so `buildUserData` will not be used in those screens. It remains useful for tests.

- [ ] **Step 3: Run all tests**

```
flutter test
```
Expected: All tests PASS (some tests may need updated call sites).

- [ ] **Step 4: Commit**

```bash
git add lib/protocol/attestation_service.dart lib/protocol/schema_config.dart test/protocol/attestation_service_test.dart
git commit -m "refactor: AttestationService accepts dynamic SchemaDefinition"
```

---

## Task 8: Dynamic Fields in Signing Screens

**Files:**
- Modify: `lib/screens/sign_screen.dart`
- Modify: `lib/screens/onchain_attest_screen.dart`
- Modify: `test/screens/onchain_attest_screen_test.dart`

### Key Details

Both screens will:
1. Read `SchemaProvider` via `context.watch<SchemaProvider>()`.
2. For each `SchemaField` in `provider.userFields`, create a `TextEditingController`.
3. Render a `TextField` per field, styled with an appropriate `keyboardType` (number for `uint256`, default for strings).
4. At submission time, build `userData` dynamically from the controllers' text values.

**Type coercion at submission:**
- `uint256` → try `BigInt.parse(text)`, throw on error
- `string` / `string[]` → raw string or split by comma
- `bytes` / `bytes[]` → raw hex string; for now accept as `String` and let the library handle encoding
- `address` / `bool` / `bytes32` → raw string

The lat/lng fields are LP base fields and are **fixed inputs** (not from the schema), so they remain hardcoded.

**Controller lifecycle:** Rebuild controllers in `didChangeDependencies` when the schema changes.

```dart
// In _SignScreenState / _OnchainAttestScreenState
List<TextEditingController> _fieldControllers = [];
List<SchemaField> _lastKnownFields = [];

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final provider = context.watch<SchemaProvider>();
  if (provider.userFields != _lastKnownFields) {
    for (final c in _fieldControllers) c.dispose();
    _fieldControllers = provider.userFields.map((_) => TextEditingController()).toList();
    _lastKnownFields = provider.userFields;
  }
}
```

Build `userData` at submission:
```dart
Map<String, dynamic> _buildUserData(SchemaProvider provider) {
  final data = <String, dynamic>{};
  for (int i = 0; i < provider.userFields.length; i++) {
    final field = provider.userFields[i];
    final text = _fieldControllers[i].text.trim();
    if (field.type == 'uint256') {
      data[field.name] = BigInt.tryParse(text) ?? BigInt.zero;
    } else if (field.type.endsWith('[]')) {
      data[field.name] = text.isEmpty ? <String>[] : text.split(',').map((s) => s.trim()).toList();
    } else {
      data[field.name] = text;
    }
  }
  return data;
}
```

Then pass to signing:
```dart
await widget.service.signOffchain(
  schema: provider.definition,
  lat: lat,
  lng: lng,
  memo: data['memo'] ?? '',
  // Note: signOffchain still uses AppSchema.buildUserData internally
  // We need to pass userData directly. See note below.
);
```

> **Important:** The `signOffchain` method calls `AppSchema.buildUserData` internally. Once schemas are dynamic, the calling screen must build `userData` and pass it directly to `_offchainSigner.signOffchainAttestation`. We will add an overload or refactor `signOffchain` to accept an explicit `userData` map. Add:
>
> ```dart
> Future<SignedOffchainAttestation> signOffchainWithData({
>   required SchemaDefinition schema,
>   required double lat,
>   required double lng,
>   required Map<String, dynamic> userData,
> }) {
>   final lpPayload = AppSchema.buildLPPayload(lat: lat, lng: lng);
>   return _offchainSigner.signOffchainAttestation(
>     schema: schema,
>     lpPayload: lpPayload,
>     userData: userData,
>   );
> }
> ```
> And equivalently for onchain: `buildAttestCallDataWithUserData(schema, lpPayload, userData)`.

- [ ] **Step 1: Update tests for `OnchainAttestScreen`**

In `test/screens/onchain_attest_screen_test.dart`, add `SchemaProvider` to the provider list in the test widget and pass it. The existing test should still pass since the default schema has a `memo` field.

- [ ] **Step 2: Run existing screen tests**

```
flutter test test/screens/onchain_attest_screen_test.dart -v
```
Note failures to understand what needs changing.

- [ ] **Step 3: Refactor `SignScreen` and `OnchainAttestScreen`**

Replace hardcoded `_memoController` with dynamic controllers. Render the field list. Build `userData` dynamically.

- [ ] **Step 4: Run all tests**

```
flutter test
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/sign_screen.dart lib/screens/onchain_attest_screen.dart test/screens/onchain_attest_screen_test.dart
git commit -m "feat: dynamic field rendering in signing screens from SchemaProvider"
```

---

## Task 9: Main Setup and Navigation

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/home_screen.dart`

### Key Details

`SchemaProvider.load()` is async. We load it alongside `SettingsService` in `_loadSettings()`. It is added to the `MultiProvider` list.

In `HomeScreen`, add a navigation button for "Schema Manager" with icon `Icons.schema` (or `Icons.tune`). Remove the existing "Register Schema" button and replace with "Schema Manager". Pass the `AttestationService` to `SchemaManagerScreen` for registration capability.

```dart
// In _LocationProtocolAppState._loadSettings()
final schemaProvider = await SchemaProvider.load();
setState(() {
  _settingsService = settingsService;
  _schemaProvider = schemaProvider;
  _runtimeNetworkConfig = RuntimeNetworkConfig.fromSettings(settingsService);
});

// In build():
ChangeNotifierProvider<SchemaProvider>.value(value: _schemaProvider!),
```

- [ ] **Step 1: Update `main.dart`**

Add `SchemaProvider? _schemaProvider;` field. Load it in `_loadSettings`. Add to `MultiProvider`.

- [ ] **Step 2: Update `HomeScreen`** navigation

Replace "Register Schema" list item with "Schema Manager" → navigates to `SchemaManagerScreen(service: service)`.

- [ ] **Step 3: Run integration smoke**

```
flutter test test/screens/home_screen_auth_test.dart -v
```
Fix any failing tests.

- [ ] **Step 4: Run full suite**

```
flutter test
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/screens/home_screen.dart
git commit -m "feat: provide SchemaProvider in widget tree and update navigation"
```

---

## Task 10: Cleanup and Memory

**Files:**
- Modify: `.ai/memory/semantic.md`
- Modify: `.ai/memory/episodic.md`

### Key Details

- [ ] **Step 1: Run full test suite one final time**

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

Add entries:
- `SchemaProvider` is the global source of truth for the active schema definition; signing screens and `AttestationService` read schema from it.
- `EasScanService` handles EAS Scan GraphQL queries; isolated from `AttestationService`.
- `SchemaManagerScreen` consolidates field management and schema registration; replaces `RegisterSchemaScreen`.

- [ ] **Step 4: Update `.ai/memory/episodic.md`**

```
[ID: SCHEMA_MANAGER] -> Follows [AppWalletProvider refactor]. 
Introduced SchemaProvider (ChangeNotifier) with SharedPreferences persistence. 
Signing screens now dynamically render fields. EasScanService queries user schemas by wallet address.
```

- [ ] **Step 5: Create walkthrough**

Create `docs/superpowers/walkthroughs/2026-03-24-schema-manager-walkthrough.md` documenting:
- What was built
- How to manually test: open Schema Manager, select a registered schema from dropdown, modify fields, observe UID change, register, navigate to Sign screen and confirm fields updated

- [ ] **Step 6: Final commit**

```bash
git add .ai/memory/ docs/superpowers/walkthroughs/
git commit -m "chore: update agent memory and add schema manager walkthrough"
```

---

## Verification Plan

### Automated Tests

Run all tests:
```
flutter test --reporter=expanded
```
All tests must PASS with zero warnings.

Run static analysis:
```
flutter analyze
```
Zero issues expected.

### Manual Verification

1. **Start the app** — `flutter run -d <device>`
2. **Navigate to Schema Manager** from the home screen.
3. **Confirm default fields** (`eventTimestamp`, `recipeType`, etc.) appear in the table.
4. **Confirm Schema UID** is displayed and can be copied.
5. **Remove a field** (e.g., `memo`). Confirm the UID updates.
6. **Add a new field** (type: `string`, name: `testField`). Confirm it appears in the table and UID updates again.
7. **Click "Reset to Default"** and confirm the 6 default fields are restored.
8. **Select a registered schema from the dropdown** (requires a connected wallet with registered schemas on EAS Scan). Confirm fields are populated and LP base fields are stripped.
9. **Navigate to Sign Attestation (Offchain)**. Confirm the dynamic fields from the Schema Manager appear as inputs.
10. **Navigate to Attest Onchain** and confirm the same dynamic fields appear.
