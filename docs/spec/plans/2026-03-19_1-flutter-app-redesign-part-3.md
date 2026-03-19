# Flutter App Redesign — Implementation Plan (Part 3)

> Continues from [Part 2](2026-03-19_1-flutter-app-redesign-part-2.md). Tasks 33–42.

---

## Part 3: Cleanup & Verification

### Sub-Phase E: Delete Old Code + Rewire

---

### Task 33: Verify all new Privy + Protocol tests pass before deletion

**Files:** None (verification only)

Before deleting old code, confirm that all new tests from Parts 1 & 2 pass independently of the old code.

- [ ] **Step 1: Run all new tests**

```bash
flutter test test/privy/ test/protocol/ test/settings/ test/screens/ -v
```

Expected: ALL PASS

- [ ] **Step 2: Verify no new code imports from old paths**

```bash
grep -r "import.*src/eas/\|import.*src/models/\|import.*src/services/\|import.*src/builder/" lib/privy/ lib/protocol/ lib/settings/ lib/widgets/ lib/screens/
```

Expected: Zero results — new code has no dependency on old code.

- [ ] **Step 3: Commit (if any fixes needed)**

```bash
git commit -am "fix: ensure new modules are independent of old code before deletion"
```

---

### Task 34: Delete obsolete `lib/src/` files

**Files to delete:**

| # | Path | Lines |
|---|------|-------|
| 1 | `lib/src/eas/abi_encoder.dart` | 219 |
| 2 | `lib/src/eas/attestation_signer.dart` | 115 |
| 3 | `lib/src/eas/constants.dart` | 10 |
| 4 | `lib/src/eas/eas_attestation.dart` | 82 |
| 5 | `lib/src/eas/eip712_signer.dart` | 1031 |
| 6 | `lib/src/eas/models.dart` | 100 |
| 7 | `lib/src/eas/offchain_signer.dart` | 158 |
| 8 | `lib/src/eas/privy_signer_adapter.dart` | 173 |
| 9 | `lib/src/eas/schema_registry.dart` | 155 |
| 10 | `lib/src/eas/tx_utils.dart` | 199 |
| 11 | `lib/src/models/location_attestation.dart` | ~50 |
| 12 | `lib/src/builder/attestation_builder.dart` | ~80 |
| 13 | `lib/src/services/location_protocol_service.dart` | ~250 |
| 14 | `lib/src/services/location_protocol_provider.dart` | ~60 |
| 15 | `lib/src/services/signing_service.dart` | ~130 |
| **Total** | | **~2,812** |

- [ ] **Step 1: Verify no new code imports from old paths**

Run:
```bash
grep -r "import.*src/eas/" lib/ --include="*.dart" | grep -v "lib/src/eas/"
grep -r "import.*src/models/" lib/ --include="*.dart" | grep -v "lib/src/models/"
grep -r "import.*src/services/" lib/ --include="*.dart" | grep -v "lib/src/services/"
grep -r "import.*src/builder/" lib/ --include="*.dart" | grep -v "lib/src/builder/"
```

Expected: Zero results for all four commands (only self-references within old code remain)

- [ ] **Step 2: Delete the files**

```bash
# Delete all old protocol code
Remove-Item -Recurse lib/src/eas/
Remove-Item -Recurse lib/src/models/
Remove-Item -Recurse lib/src/services/
Remove-Item -Recurse lib/src/builder/
```

- [ ] **Step 3: Delete empty parent directory**

If `lib/src/` only contained `privy_auth_modal/` plus the now-deleted folders:

```bash
# Move the privy_auth_modal module to lib/privy/ if not already done in Task 1
# If Task 1 already moved it, then lib/src/ should now be empty
# If lib/src/privy_auth_modal still exists, copy it first:
#   Copy-Item -Recurse lib/src/privy_auth_modal/ lib/privy/
# Then:
Remove-Item -Recurse lib/src/
```

> **Note:** If Task 1 already moved `privy_auth_modal` to `lib/privy/`, then `lib/src/` is now empty and can be deleted outright. If a copy still exists at `lib/src/privy_auth_modal/`, ensure the new `lib/privy/` location is the one in use before deleting.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: delete ~2,800 lines of obsolete custom protocol code from lib/src/"
```

---

### Task 35: Delete obsolete test files

**Files to delete:**

| # | Path |
|---|------|
| 1 | `test/abi_encoder_test.dart` |
| 2 | `test/attestation_builder_test.dart` |
| 3 | `test/attestation_signer_test.dart` |
| 4 | `test/eip712_signer_test.dart` |

These tests exclusively test code in the deleted `lib/src/eas/` and `lib/src/builder/` directories.

- [ ] **Step 1: Verify no references from kept tests**

Run:
```bash
grep -r "abi_encoder_test\|attestation_builder_test\|attestation_signer_test\|eip712_signer_test" test/ --include="*.dart"
```

Expected: Zero results (tests are standalone).

- [ ] **Step 2: Delete the test files**

```bash
Remove-Item test/abi_encoder_test.dart
Remove-Item test/attestation_builder_test.dart
Remove-Item test/attestation_signer_test.dart
Remove-Item test/eip712_signer_test.dart
```

- [ ] **Step 3: Also consider updating `test/round_trip_test.dart`**

If `round_trip_test.dart` imports from `lib/src/eas/` or `lib/src/services/`, it must be updated to use the new `AttestationService`. Read the file first to determine.

Likely update:
```dart
// test/round_trip_test.dart — update imports
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';
// Remove old imports:
// import 'package:location_protocol_flutter_app/src/eas/...';
// import 'package:location_protocol_flutter_app/src/services/...';
```

- [ ] **Step 4: Also consider updating `test/signing_verification_baseline_test.dart`**

Same as above — check imports and rewrite to use new module paths.

- [ ] **Step 5: Also consider `test/location_protocol_service_test.dart`**

If this test file tests the old `LocationProtocolService`, it needs to be rewritten entirely or deleted. Decide based on content:
- If it tests offchain sign + verify → rewrite to use `AttestationService`
- If it tests onchain ops → likely needs to be deleted (hard to unit-test without RPC mock)

- [ ] **Step 6: Also consider `test/privy_signer_adapter_test.dart`**

Already has 492 lines of comprehensive testing with mock RPC injection. This should be updated to test `PrivySigner` from `lib/privy/privy_signer.dart` instead of `lib/src/eas/privy_signer_adapter.dart`.

Key changes:
- Update import paths
- Adapt to new `PrivySigner` API (which should expose the same mock injection pattern)
- Keep the golden fixture validation

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: delete obsolete test files, update remaining tests for new module paths"
```

---

### Task 36: Clean `pubspec.yaml` — remove unused dependencies

**Files:**
- Modify: `pubspec.yaml`

> Note: `shared_preferences` was already added in Task 16 (Part 1). This task handles post-deletion cleanup only.

- [ ] **Step 1: Remove `convert` if no longer used**

After the old code is deleted, check whether `convert` is still imported anywhere:

```bash
grep -r "import.*package:convert" lib/ --include="*.dart"
```

If zero results, remove `convert: ^3.1.1` from `pubspec.yaml` and run `flutter pub get` again.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: update pubspec — add shared_preferences, clean unused deps"
```

---

### Sub-Phase F: Final Verification

---

### Task 37: `flutter analyze` — zero issues

**Files:** None (verification only)

- [ ] **Step 1: Run `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: If there are issues, fix them**

Common issues after large refactors:
- Unused imports → remove them
- Missing imports → add them
- Type mismatches → fix to use library types
- Deprecated API usage → update

- [ ] **Step 3: Commit fixes if any**

```bash
git commit -am "fix: resolve flutter analyze issues"
```

---

### Task 38: `flutter test` — all pass

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

Run: `flutter test -v`
Expected: ALL tests pass, zero failures.

- [ ] **Step 2: If failures, fix them**

Likely failure sources:
- Import path changes not reflected in test files
- Missing mock setup for new types
- PrivySigner adapter changes not reflected in adapter test

- [ ] **Step 3: Commit fixes if any**

```bash
git commit -am "fix: resolve test failures"
```

---

### Task 39: Run test coverage check

**Files:** None (verification only)

- [ ] **Step 1: Run with coverage**

Run: `flutter test --coverage`
Then: `dart run coverage:format_coverage --lcov -i coverage/ -o coverage/lcov.info --packages .dart_tool/package_config.json`

Review coverage of new files:
- `lib/protocol/attestation_service.dart` — should be well covered
- `lib/protocol/schema_config.dart` — should be covered
- `lib/privy/privy_signer.dart` — basic coverage from adapter test
- `lib/settings/settings_service.dart` — should be well covered

---

### Task 40: Generate walkthrough

**Files:**
- Modify: `walkthrough.md`

- [ ] **Step 1: Update the walkthrough**

Replace the contents of `walkthrough.md` with a current walkthrough of the new app architecture:

```markdown
# Location Protocol Flutter App — Walkthrough

## Architecture

The app is a thin Flutter integration layer over the `location_protocol` Dart library.

### Module Structure

```
lib/
├── main.dart                    # App entry point, Privy auth wrapper
├── privy/                       # Privy authentication module (reusable)
│   ├── privy_module.dart        # Barrel export
│   ├── privy_auth_config.dart   # Config model
│   ├── privy_auth_state.dart    # ChangeNotifier for auth state
│   ├── privy_auth_provider.dart # InheritedNotifier widget
│   ├── privy_manager.dart       # Singleton SDK wrapper
│   ├── privy_signer.dart        # Signer adapter for library
│   └── flows/                   # Login flow widgets
├── protocol/                    # Protocol bridge module
│   ├── protocol_module.dart     # Barrel export
│   ├── attestation_service.dart # Service wrapping library operations
│   └── schema_config.dart       # App-specific schema definition
├── settings/                    # Dev/test settings
│   ├── settings_service.dart    # SharedPreferences persistence
│   └── settings_screen.dart     # Settings UI
├── widgets/                     # Shared widgets
│   ├── attestation_result_card.dart
│   ├── chain_selector.dart
│   ├── private_key_import_dialog.dart
│   └── external_sign_dialog.dart
└── screens/                     # Feature screens
    ├── home_screen.dart
    ├── sign_screen.dart
    ├── verify_screen.dart
    ├── onchain_attest_screen.dart
    ├── register_schema_screen.dart
    └── timestamp_screen.dart
```

### Signer Strategies

The app supports three signing strategies, all implementing the library's `Signer` interface:

1. **LocalKeySigner** — Direct private key (from library)
2. **PrivySigner** — Via Privy embedded wallet
3. **ExternalWalletSigner** — User pastes a signature from MetaMask/etc.

### Key Flows

- **Sign Offchain**: HomeScreen → SignScreen → `AttestationService.signOffchain()` → displays `AttestationResultCard`
- **Verify**: HomeScreen → VerifyScreen → paste JSON → `AttestationService.verifyOffchain()` → displays result
- **Attest Onchain**: HomeScreen → OnchainAttestScreen → builds calldata → `eth_sendTransaction` via Privy → shows tx hash
- **Register Schema**: HomeScreen → RegisterSchemaScreen → builds register calldata → submits
- **Timestamp**: HomeScreen → TimestampScreen → builds timestamp calldata → submits
```

- [ ] **Step 2: Commit**

```bash
git add walkthrough.md
git commit -m "docs: update walkthrough for new architecture"
```

---

### Task 41: Memory consolidation

**Files:**
- Modify: `.ai/memory/episodic.md`

- [ ] **Step 1: Update episodic memory**

Add entry documenting what was accomplished in this phase:

```markdown
## 2025-XX-XX — Flutter App Redesign (Phase 1)

### What happened
- Removed ~2,800 lines of custom protocol code (EAS, EIP-712, ABI encoding)
- Created `AttestationService` as thin bridge to `location_protocol` library
- Extracted Privy auth module to `lib/privy/` with barrel export
- Created `PrivySigner` adapter implementing library's `Signer` interface
- Added `SettingsService` with SharedPreferences
- Built 6 screens: Sign, Verify, OnchainAttest, RegisterSchema, Timestamp, Settings
- All tests pass, zero analyzer issues

### Key Learnings
- `location_protocol` LPVersion.current is '0.2.0', not '1.0.0' as PRD stated
- Library's `OffchainSigner.signAttestation()` handles the complete EIP-712 pipeline
- Privy`s wallet.provider.request() returns `Result` requiring `fold()`
- `SignedOffchainAttestation` has no `fromJson()` — manual parsing needed for verify screen
```

---

### Task 42: Final checkpoint

- [ ] **Step 1: Run full verification**

```bash
flutter analyze
flutter test -v
```

Both must pass with zero issues/failures.

- [ ] **Step 2: Review file tree**

```bash
Get-ChildItem -Recurse lib/ -Filter *.dart | Select-Object FullName
```

Expected new structure:
```
lib/main.dart
lib/privy/privy_module.dart
lib/privy/privy_auth_config.dart
lib/privy/privy_auth_state.dart
lib/privy/privy_auth_provider.dart
lib/privy/privy_manager.dart
lib/privy/privy_signer.dart
lib/privy/flows/*.dart
lib/protocol/protocol_module.dart
lib/protocol/attestation_service.dart
lib/protocol/schema_config.dart
lib/settings/settings_service.dart
lib/settings/settings_screen.dart
lib/widgets/attestation_result_card.dart
lib/widgets/chain_selector.dart
lib/widgets/private_key_import_dialog.dart
lib/widgets/external_sign_dialog.dart
lib/screens/home_screen.dart
lib/screens/sign_screen.dart
lib/screens/verify_screen.dart
lib/screens/onchain_attest_screen.dart
lib/screens/register_schema_screen.dart
lib/screens/timestamp_screen.dart
```

No `lib/src/` directory should exist.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: Flutter App Redesign Phase 1 complete — thin integration layer"
```

---

## Summary

| Sub-Phase | Tasks | Description |
|-----------|-------|-------------|
| A (Part 1) | 1–5 | Privy extraction to `lib/privy/` |
| B (Part 1) | 6–17 | Protocol bridge: `AttestationService`, `PrivySigner`, schema config, offchain/onchain wiring |
| C (Part 2) | 18–25 | Widget rewrites + screen rewrites (offchain) |
| D (Part 2) | 26–32 | Settings service/screen + onchain screens |
| E (Part 3) | 33–36 | Delete old code, update pubspec |
| F (Part 3) | 37–42 | Verification, walkthrough, memory |

**Total tasks: 42**
**Estimated lines deleted: ~2,800**
**Estimated lines added: ~2,200**
**Net reduction: ~600 lines**
