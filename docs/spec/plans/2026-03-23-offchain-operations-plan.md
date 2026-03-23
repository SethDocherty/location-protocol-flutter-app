# Offchain Operations Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge offchain signing actions into a single button by abstracting all three wallet connection types (Privy, Reown, Private Key) into a unified `AppWalletProvider`.

**Architecture:** Create a `ChangeNotifier` called `AppWalletProvider` that securely tracks the active `ConnectionType` and exposes a unified `.getSigner()` and `.sendTransaction()` method. Update the Login Modal to support private key imports, consolidate the `HomeScreen` UI by removing disparate connection buttons, and decouple onchain screens from Privy's concrete `EmbeddedEthereumWallet` so that Reown external wallets can natively transact.

**Tech Stack:** Flutter, Provider, Privy SDK, Reown AppKit.

---

## File Structure
- `lib/providers/app_wallet_provider.dart` (NEW): Central state tracking the active connection type and abstracting wallet methods.
- `test/providers/app_wallet_provider_test.dart` (NEW): Unit tests for the AppWalletProvider logic.
- `lib/settings/settings_service.dart` (MOD): Removes private key persistence logic.
- `test/settings_service_test.dart` (MOD): Removes private key persistence tests.
- `lib/settings/settings_screen.dart` (MOD): Removes the "Add Private Key" input UI.
- `lib/privy/login_modal.dart` (MOD): Adds "Import Private Key" to the Privy login UI list.
- `lib/widgets/private_key_import_dialog.dart` (MOD): Stores imported keys strictly in-memory via `AppWalletProvider`.
- `lib/screens/home_screen.dart` (MOD): Consolidates all Offchain buttons into a unified UI path based on `AppWalletProvider`.
- `lib/screens/onchain_attest_screen.dart` (MOD): Updates to use `AppWalletProvider.sendTransaction` instead of `EmbeddedEthereumWallet`.
- `lib/screens/register_schema_screen.dart` (MOD): Updates to use `AppWalletProvider.sendTransaction`.
- `lib/screens/timestamp_screen.dart` (MOD): Updates to use `AppWalletProvider.sendTransaction`.

---

### Task 1: Clean up SettingsService and Tests

**Files:**
- Modify: `test/settings_service_test.dart`
- Modify: `lib/settings/settings_service.dart`

- [ ] **Step 1: Write the failing test**

Modify `test/settings_service_test.dart` to completely remove any test blocks labelled "privateKeyHex", such as `test('privateKeyHex saves and loads correctly', ...)`. Because we are removing the feature, no new test needs to fail; we are enforcing deletion.

- [ ] **Step 2: Run test to verify cleanup**

Run: `flutter test test/settings_service_test.dart`
Expected: PASS (Tests should pass after privateKey tests are removed).

- [ ] **Step 3: Remove minimal implementation from Service**

Modify `lib/settings/settings_service.dart`. Delete the following completely:
```dart
  static const String _privateKeyHexKey = 'privateKeyHex';
  String? get privateKeyHex => _prefs.getString(_privateKeyHexKey);
  Future<void> setPrivateKeyHex(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(_privateKeyHexKey);
    } else {
      await _prefs.setString(_privateKeyHexKey, value);
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter analyze lib/settings/settings_service.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add test/settings_service_test.dart lib/settings/settings_service.dart
git commit -m "refactor: remove persistent private key from settings service tests and impl"
```

---

### Task 2: Remove Settings Screen Private Key UI

**Files:**
- Modify: `test/screens/settings_screen_test.dart` (If exists)
- Modify: `lib/settings/settings_screen.dart`

- [ ] **Step 1: Review failing test**

If `test/screens/settings_screen_test.dart` exists and tests for a "Private Key" text field, remove that test assertion.

- [ ] **Step 2: Run test**

Run: `flutter test`
Expected: Output showing no UI test failures relating to the private key input.

- [ ] **Step 3: Write minimal implementation**

Modify `lib/settings/settings_screen.dart`. Remove the `TextField` block that manages `privateKeyHex`, as well as any initialization of `_privateKeyHexController`.

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/settings/settings_screen.dart`
Expected: PASS without compile errors.

- [ ] **Step 5: Commit**

```bash
git add lib/settings/settings_screen.dart
git commit -m "refactor: drop private key text input from settings screen"
```

---

### Task 3: Create AppWalletProvider

**Files:**
- Create: `test/providers/app_wallet_provider_test.dart`
- Create: `lib/providers/app_wallet_provider.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/providers/app_wallet_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';

void main() {
  test('AppWalletProvider default state is none', () {
    final provider = AppWalletProvider();
    expect(provider.connectionType, ConnectionType.none);
    expect(provider.isConnected, false);
    expect(provider.canSendTransactions, false);
  });

  test('setPrivateKey switches connection to privateKey', () {
    final provider = AppWalletProvider();
    provider.setPrivateKey('0xabc');
    expect(provider.connectionType, ConnectionType.privateKey);
    expect(provider.isConnected, true);
    expect(provider.walletAddress, isNotNull);
    expect(provider.canSendTransactions, false); // Private keys cannot send tx
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/app_wallet_provider_test.dart`
Expected: Error (AppWalletProvider not found)

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/providers/app_wallet_provider.dart
import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';

enum ConnectionType { privy, external, privateKey, none }

class AppWalletProvider extends ChangeNotifier {
  String? _privateKeyHex;
  // TODO: Add Privy and Reown service references in advanced wiring
  // For now, minimal passing state for private key
  
  ConnectionType get connectionType {
    if (_privateKeyHex != null) return ConnectionType.privateKey;
    return ConnectionType.none;
  }
  
  bool get isConnected => connectionType != ConnectionType.none;
  bool get canSendTransactions => connectionType == ConnectionType.privy || connectionType == ConnectionType.external;
  String? get walletAddress {
    if (_privateKeyHex != null) return LocalKeySigner(privateKeyHex: _privateKeyHex!).address;
    return null;
  }
  
  void setPrivateKey(String key) {
    _privateKeyHex = key;
    notifyListeners();
  }

  void logout() {
    _privateKeyHex = null;
    notifyListeners();
  }
  
  AttestationSigner? getSigner(int targetChainId) {
    if (_privateKeyHex != null) return LocalKeySigner(privateKeyHex: _privateKeyHex!);
    return null;
  }

  Future<String?> sendTransaction(Map<String, dynamic> txRequest) async {
    throw UnimplementedError('Configure privy/reown to send transaction');
  }
}
```
*Note: The actual implementation in the agent's step will require wiring `PrivyAuthProvider` and `ReownService` via the constructor or `update` methods in Provider.*

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/app_wallet_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/providers/app_wallet_provider.dart test/providers/app_wallet_provider_test.dart
git commit -m "feat: implement AppWalletProvider base logic"
```

---

### Task 4: Private Key Import in Login Modal

**Files:**
- Modify: `lib/privy/login_modal.dart`
- Modify: `lib/widgets/private_key_import_dialog.dart`

- [x] **Step 1: Write UI tests (if applicable) or proceed**
Given Flutter UI testing complexities with bottom sheets, rely on static analysis and manual verification.

- [x] **Step 2: Run test to verify it fails**
N/A

- [x] **Step 3: Write minimal implementation**

In `lib/privy/login_modal.dart`, inside `_buildSelector()`, add a new list item:
```dart
ListTile(
  leading: const Icon(Icons.key),
  title: const Text('Import Private Key'),
  onTap: () async {
    final key = await showPrivateKeyImportDialog(context);
    if (key != null && key.isNotEmpty && context.mounted) {
      context.read<AppWalletProvider>().setPrivateKey(key);
      Navigator.of(context).pop();
    }
  },
),
```
Ensure `showPrivateKeyImportDialog` no longer relies on `SettingsService.setPrivateKeyHex`. 

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter analyze lib/privy/login_modal.dart lib/widgets/private_key_import_dialog.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/privy/login_modal.dart lib/widgets/private_key_import_dialog.dart
git commit -m "feat: add Import Private Key mechanism via login modal and Provider"
```

---

### Task 5: Decouple Onchain Screens from Privy

**Files:**
- Modify: `lib/screens/onchain_attest_screen.dart`
- Modify: `lib/screens/register_schema_screen.dart`
- Modify: `lib/screens/timestamp_screen.dart`

- [ ] **Step 1: Write/Review tests**
Ensure existing UI tests for these screens are updated if they pass `EmbeddedEthereumWallet`.

- [ ] **Step 2: Write minimal implementation**

For each screen, replace the constructor arguments:
```dart
  const OnchainAttestScreen({
    super.key,
    required this.service,
-   required this.wallet,
  });
```
And replace the submit execution:
```dart
- final result = await widget.wallet.provider.request(EthereumRpcRequest(method: 'eth_sendTransaction', params: [jsonEncode(txRequest)]));
+ final hash = await context.read<AppWalletProvider>().sendTransaction(txRequest);
+ if (hash != null) setState(() => _txHash = hash);
```

- [ ] **Step 3: Run test to verify**

Run: `flutter analyze lib/screens/onchain_attest_screen.dart lib/screens/register_schema_screen.dart lib/screens/timestamp_screen.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/screens/onchain_attest_screen.dart lib/screens/register_schema_screen.dart lib/screens/timestamp_screen.dart
git commit -m "refactor: abstract onchain screens to utilize provider sendTransaction"
```

---

### Task 6: Refactor HomeScreen UI

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Write/Review tests**
If `test/screens/home_screen_test.dart` exists, update expectations to test for a single "Sign Offchain Attestation" button instead of three.

- [ ] **Step 2: Run test to verify it fails**
Run: `flutter test test/screens/home_screen_test.dart` (if exists)

- [ ] **Step 3: Write minimal implementation**

In `lib/screens/home_screen.dart`:
1. Use `final walletProvider = context.watch<AppWalletProvider>();`.
2. Wrap unauthenticated state in `if (!walletProvider.isConnected) { return _buildLoginButton(); }`.
3. Wrap authenticated state. Replace previously separate sign buttons (`_buildSignWithWalletButton`, etc.) with a single `_buildSignOffchainButton(walletProvider)`.
4. Wrap Onchain operation buttons with:
```dart
if (walletProvider.canSendTransactions) ...[
  _buildOnchainAttestButton(),
  // ...
]
```
5. Inside `_buildSignOffchainButton`, properly extract the `signer`: `final signer = walletProvider.getSigner(_chainId);` and construct `AttestationService`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter analyze lib/screens/home_screen.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "refactor: merge offchain actions and unify home screen connection state"
```
