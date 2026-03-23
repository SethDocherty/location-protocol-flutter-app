# Reown AppKit Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Reown AppKit to provide a modern, deep-linking UI modal for signing typed data with external wallets like MetaMask, replacing the manual copy/paste fallback.

**Architecture:** Create a UI-layer `ReownService` to manage the `ReownAppKitModal`. In `HomeScreen`, instantiate this service and inject its sign method into the existing `ExternalWalletSigner`.

**Tech Stack:** Flutter, `reown_appkit`

---

### Task 1: Setup Dependencies & Environment

**Files:**
- Modify: `pubspec.yaml`
- Modify: `.env-example`
- Modify: `.env` (User will manually update actual `.env` if not in source control)

- [ ] **Step 1: Write the failing test** (N/A for pubspec, skip)
- [ ] **Step 2: Add `reown_appkit` dependency**
Modify `pubspec.yaml` to include `reown_appkit: ^1.2.0` (or latest stable compatible version).

- [ ] **Step 3: Add `REOWN_PROJECT_ID` placeholder**
Modify `.env-example` to include `REOWN_PROJECT_ID=your_reown_project_id_here`. Add the user's specific ID to the local `.env` file (`REOWN_PROJECT_ID=ee0005ba04040be6f28436e84c2f7f0a`).

- [ ] **Step 4: Resolve dependencies**
Run: `flutter pub get`
Expected: Successful resolution.

- [ ] **Step 5: Commit**
```bash
git add pubspec.yaml .env-example
git commit -m "chore: add reown_appkit dependency and env variables"
```

### Task 2: Create ReownService Wrapper

**Files:**
- Create: `lib/services/reown_service.dart`

- [ ] **Step 1: Write the failing test** (N/A, testing external UI SDKs requires complex mocking, we will manually verify functionality).
- [ ] **Step 2: Implement `ReownService`**
Create `lib/services/reown_service.dart`.
Include the following:
```dart
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ReownService {
  late ReownAppKitModal appKitModal;
  
  Future<void> initialize(BuildContext context) async {
    final projectId = dotenv.env['REOWN_PROJECT_ID'] ?? '';
    
    appKitModal = ReownAppKitModal(
      context: context,
      projectId: projectId,
      metadata: const PairingMetadata(
        name: 'Location Protocol',
        description: 'Sign location attestations',
        url: 'https://locationprotocol.com/',
        icons: ['https://example.com/logo.png'],
        redirect: Redirect(
          native: 'locationprotocol://',
          universal: 'https://locationprotocol.com',
        ),
      ),
    );
    await appKitModal.init();
  }

  Future<EIP712Signature> signTypedData(BuildContext context, Map<String, dynamic> typedData) async {
    // If not connected, force open modal
    if (!appKitModal.isConnected) {
      await appKitModal.openModalView(); // Wait for user to connect
    }
    
    if (!appKitModal.isConnected) {
      throw Exception('User cancelled connection');
    }

    final sessionTopic = appKitModal.session!.topic;
    final address = appKitModal.session!.address; // Note: specific path to address depends on appKit version

    final response = await appKitModal.request(
      topic: sessionTopic,
      chainId: appKitModal.selectedChain?.chainId ?? 'eip155:11155111',
      request: SessionRequestParams(
        method: 'eth_signTypedData_v4',
        params: [address, typedData],
      ),
    );
    
    if (response == null) {
      throw Exception('Signing cancelled or failed');
    }
    
    // Parse the 65-byte hex signature into EIP712Signature
    // The library expects it to be split into v, r, s
    return EIP712Signature.fromHex(response.toString());
  }
}
```

- [ ] **Step 3: Analyze code for compiler errors**
Run: `flutter analyze lib/services/reown_service.dart`
Expected: No errors (fix minor syntax/property issues if API has updated).

- [ ] **Step 4: Commit**
```bash
git add lib/services/reown_service.dart
git commit -m "feat: implement ReownService wrapper for appkit"
```

### Task 3: Integrate ReownService into HomeScreen

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Write the failing test** (N/A)
- [ ] **Step 2: Update `HomeScreen` to initialize and use `ReownService`**
In `lib/screens/home_screen.dart`, add a `ReownService _reownService = ReownService();` to `_HomeScreenState`.
Initialize it in `initState()` (or `didChangeDependencies` if context is needed).
Update `_buildExternalWalletSignButton`:
```dart
      onPressed: () {
        if (auth.walletAddress == null) {
          // ... 
        }
        final signer = ExternalWalletSigner(
          walletAddress: auth.walletAddress!,
          onSignTypedData: (typedData) async {
            return await _reownService.signTypedData(context, typedData);
          },
        );
        // ... navigation to SignScreen
      }
```

- [ ] **Step 3: Verify build**
Run: `flutter analyze lib/screens/home_screen.dart`
Expected: 0 issues.

- [ ] **Step 4: Commit**
```bash
git add lib/screens/home_screen.dart
git commit -m "feat: integrate ReownService into HomeScreen for external signing"
```

### Task 4: Clean up Legacy Code (Optional)

**Files:**
- Modify: `lib/widgets/external_sign_dialog.dart` (delete)

- [ ] **Step 1: Delete file if unused**
Run: `rm lib/widgets/external_sign_dialog.dart`

- [ ] **Step 2: Remove references**
Remove `import '../widgets/external_sign_dialog.dart';` from `home_screen.dart`.

- [ ] **Step 3: Run full tests**
Run: `flutter test`
Expected: All pass.

- [ ] **Step 4: Commit**
```bash
git rm lib/widgets/external_sign_dialog.dart
git add lib/screens/home_screen.dart
git commit -m "refactor: remove legacy external sign dialog"
```
