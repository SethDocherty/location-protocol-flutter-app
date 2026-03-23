# Gas Sponsorship Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modify the application to dynamically append `sponsor: true` to the transaction requests sent via the Privy wallet when the `GAS_SPONSORSHIP` environment variable is set to true.

**Architecture:** Inject `GAS_SPONSORSHIP` directly from `flutter_dotenv` into `AttestationService` either during instantiation or directly within the class methods. When building `txRequest` maps in `buildTxRequest`, we will append the `"sponsor": true` flag for Privy to recognize and cover the gas fees for the embedded wallet transaction.

**Tech Stack:** Dart, Flutter, `flutter_dotenv`, `privy_flutter`.

---

### Task 1: Update `AttestationService` to Support Gas Sponsorship

**Files:**
- Modify: `lib/protocol/attestation_service.dart`

- [ ] **Step 1: Write the failing test**

```dart
// Modify `test/protocol/attestation_service_test.dart` (or create if missing)
// to test that `buildTxRequest` includes the sponsor flag when gas sponsorship is enabled.
test('buildTxRequest includes sponsor flag when sponsorGas is true', () {
  final service = AttestationService(
    signer: MockSigner(),
    chainId: 84532, // Base Sepolia
    sponsorGas: true,
  );
  
  final tx = service.buildTxRequest(callData: Uint8List(0), contractAddress: '0x123');
  expect(tx['sponsor'], isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/protocol/attestation_service_test.dart`
Expected: FAIL due to undefined parameter `sponsorGas`.

- [ ] **Step 3: Write minimal implementation**

```dart
// In `lib/protocol/attestation_service.dart`:
class AttestationService {
  final Signer signer;
  final int chainId;
  final String? fallbackRpcUrl;
  final bool sponsorGas; // ADD THIS

  AttestationService({
    required this.signer,
    required this.chainId,
    this.fallbackRpcUrl,
    this.sponsorGas = false, // ADD THIS
    http.Client? httpClient,
  }) // ...

  Map<String, dynamic> buildTxRequest({
    required Uint8List callData,
    required String contractAddress,
  }) {
    final tx = TxUtils.buildTxRequest(
      to: contractAddress,
      data: callData,
      from: signer.address,
    );
    
    final enhancedTx = {...tx, 'chainId': '0x${chainId.toRadixString(16)}'};
    if (sponsorGas) {
      enhancedTx['sponsor'] = true;
    }
    return enhancedTx;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/protocol/attestation_service.dart test/protocol/attestation_service_test.dart
git commit -m "feat: add sponsorGas flag to AttestationService"
```

---

### Task 2: Pass `GAS_SPONSORSHIP` from Environment to `AttestationService`

**Files:**
- Modify: `lib/protocol/attestation_service_provider.dart` (or wherever it is instantiated, depending on project structure) and `.env.example`

- [ ] **Step 1: Find where `AttestationService` is initialized and update**

```dart
// Check `lib/screens/home_screen.dart` or `lib/widgets/...` 
// E.g.
import 'package:flutter_dotenv/flutter_dotenv.dart';

final isSponsored = dotenv.env['GAS_SPONSORSHIP']?.toLowerCase() == 'true';
final service = AttestationService(
  signer: signer,
  chainId: chainId,
  fallbackRpcUrl: rpcUrl,
  sponsorGas: isSponsored,
);
```

- [ ] **Step 2: Update `.env` / `.env.example`**
Add the following to the top or bottom of `.env` and `.env.example`:
```
# Set to 'true' to enable gas sponsorship for Privy embedded wallet transactions.
GAS_SPONSORSHIP=false
```

- [ ] **Step 3: Run the application to ensure it builds**

Run: `flutter test` and/or verify compile check `flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/ .env.example
git commit -m "feat: read GAS_SPONSORSHIP from dotenv to configure service"
```

---
