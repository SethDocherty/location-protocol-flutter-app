# Automate SIWE Login via ReownAppKit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate the SIWE (Sign-In with Ethereum) login flow using the existing `ReownService` to replace the manual copy-paste UI.

**Architecture:** We will extend `ReownService` to support EIP-191 `personal_sign` and modify `SiweFlow` to automatically detect the external wallet address, generate the SIWE message, prompt the user to sign via WalletConnect, and submit the signature to Privy.

**Tech Stack:** Flutter, Dart, Privy SDK, Reown AppKit

---

### Task 1: Add `personalSign` to `ReownService`

**Files:**
- Modify: `lib/services/reown_service.dart`

- [ ] **Step 1: Write the implementation**

Add the `personalSign` method to `ReownService`.

```dart
import 'dart:convert';
import 'package:convert/convert.dart';

// ... inside ReownService

  Future<String> personalSign(BuildContext context, String message) async {
    if (!appKitModal.isConnected) {
      await appKitModal.openModalView(); 
    }
    
    if (!appKitModal.isConnected) {
      throw Exception('User cancelled connection');
    }

    final sessionTopic = appKitModal.session!.topic ?? '';
    final address = appKitModal.session!.getAddress('eip155') ?? '';
    
    // personal_sign expects the message as a hex string
    final messageHex = '0x\${hex.encode(utf8.encode(message))}';

    final response = await appKitModal.request(
      topic: sessionTopic,
      chainId: appKitModal.selectedChain?.chainId ?? 'eip155:11155111',
      request: SessionRequestParams(
        method: 'personal_sign',
        params: [messageHex, address],
      ),
    );
    
    if (response == null) {
      throw Exception('Signing cancelled or failed');
    }
    
    return response.toString();
  }
```

- [ ] **Step 2: Verify Compilation**
Run: `flutter analyze`
Expected: PASS

- [ ] **Step 3: Commit**
```bash
git add lib/services/reown_service.dart
git commit -m "feat: add personalSign to ReownService"
```

---

### Task 2: Refactor `SiweFlow` UI and Logic

**Files:**
- Modify: `lib/privy/flows/siwe_flow.dart`

- [ ] **Step 1: Refactor State**
Remove `_addressController`, `_signatureController`, `_siweMessage`, `_siweParams` and `_walletClientType`.
Remove `_step` enum. The flow now happens via a single method.

- [ ] **Step 2: Write automated login sequence**
Initialize `ReownService` and write the login logic.

```dart
// Needs import:
import '../../services/reown_service.dart';

// Inside _SiweFlowState:
  final ReownService _reownService = ReownService();

  @override
  void initState() {
    super.initState();
    _reownService.initialize(context);
  }

  Future<void> _loginWithExternalWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Get Address
      final address = await _reownService.connectAndGetAddress();
      if (address == null || address.isEmpty) {
        setState(() {
          _error = 'External wallet connection failed or cancelled.';
          _loading = false;
        });
        return;
      }

      // 2. Generate SIWE Message
      final params = SiweMessageParams(
        appDomain: widget.config.siweAppDomain,
        appUri: widget.config.siweAppUri,
        chainId: '1',
        walletAddress: address,
      );

      final generateResult = await PrivyManager().privy.siwe.generateSiweMessage(params);
      
      String siweMessage = '';
      bool hasError = false;
      generateResult.fold(
        onSuccess: (message) => siweMessage = message,
        onFailure: (error) {
          hasError = true;
          setState(() {
            _error = error.message;
            _loading = false;
          });
        },
      );
      if (hasError) return;

      // 3. Request personal_sign via ReownService
      if (!mounted) return;
      final signature = await _reownService.personalSign(context, siweMessage);

      // 4. Submit to Privy
      final loginResult = await PrivyManager().privy.siwe.loginWithSiwe(
        message: siweMessage,
        signature: signature,
        params: params,
        metadata: const WalletLoginMetadata(walletClientType: WalletClientType.other),
      );

      loginResult.fold(
        onSuccess: (_) => widget.onComplete(null),
        onFailure: (error) {
          setState(() {
            _error = error.message;
            _loading = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }
```

- [ ] **Step 3: Update `build` method**
Replace `_buildAddressStep()` and `_buildSignStep()` with a single unified UI widget:

```dart
  // Replace the _step-based conditional logic in build() to exclusively show this step.
  Widget _buildUnifiedStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sign in with your external wallet to securely authenticate.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _loginWithExternalWallet,
          icon: _loading 
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
              : const Icon(Icons.account_balance_wallet),
          label: const Text('Connect & Sign In'),
        ),
      ],
    );
  }
```

- [ ] **Step 4: Verify Compilation and Tests**
Run: `flutter analyze` and `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**
```bash
git add lib/privy/flows/siwe_flow.dart
git commit -m "feat: automate siwe login flow using reown external wallet"
```
