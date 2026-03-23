# Reown AppKit Integration Design

## Overview
Currently, the Location Protocol Flutter App relies on a copy/paste fallback dialog for signing typed data with an external wallet like MetaMask. The `ExternalWalletSigner` interface orchestrates this by invoking a callback to the UI layer, but the UX is cumbersome. 

This design replaces the manual copy/paste dialog with the **Reown AppKit** modal, providing seamless UI and deep-linking capabilities to external wallets (like MetaMask) while keeping the core protocol layer completely decoupled from any specific UI or modal logic.

## Goals
- Provide a native-feeling, elegant UI modal for selecting external wallets.
- Deep-link seamlessly to MetaMask (or other wallets) to approve connections and sign requests.
- Retain the clean separation of concerns: the core `location_protocol` service layer should not import or depend on Reown UI packages.
- Tighten the scope to just "Sign with External Wallet" (offchain attestations) for now. Login / Onchain functionality can be expanded later.

## Architecture & Approach

We will follow an **App-Layer Managed UI (Injection)** architectural approach:

### 1. The `ReownService` (UI / App Layer)
A dedicated service class will be created in the application layer (e.g., `lib/services/reown_service.dart`).
- **Initialization**: It will initialize the `ReownAppKitModal` using the Reown Project ID (loaded securely from `.env`).
- **Functionality**: It will expose a method, `Future<EIP712Signature> signTypedData(BuildContext context, Map<String, dynamic> typedData)`.
- **Flow**: 
  1. Opens the AppKit modal (`appKit.open()`) if not connected.
  2. Once connected, uses `appKit.request()` to send the `eth_signTypedData_v4` JSON-RPC payload.
  3. Returns the resulting hex signature parsed into an `EIP712Signature`.

### 2. The Bridge (Dependency Injection)
The original `ExternalWalletSigner` inside `location_protocol` will remain structurally identical. 
- During `AttestationService` dependency injection, the `ExternalWalletSigner` will be instantiated, and its `onSignTypedData` callback will be wired to invoke the `ReownService.signTypedData(...)` execution.

### 3. Setup Requirements
- Update `pubspec.yaml` to include `reown_appkit`.
- Add `REOWN_PROJECT_ID` to `.env` and `.env-example`.
- Ensure iOS `Podfile` adjustments (e.g., setting iOS version to 13.0) and any Android Manifest query configurations are present as per the Reown SDK requirements.

## Sequence Flow
1. User taps "Sign with External Wallet" in the UI.
2. `ExternalWalletSigner.signTypedData()` is invoked by the protocol layer.
3. The injected callback triggers `ReownService.signTypedData()`.
4. AppKit Modal opens -> User selects MetaMask -> Deep-links to MetaMask app to approve connection.
5. User is routed back to the Flutter app.
6. `appKit.request()` triggers -> Deep-links back to MetaMask with the structured typed data for signing.
7. User signs -> Routed back to Flutter app.
8. Signature is returned through the callback to complete the `location_protocol` attestation flow.

## Future Considerations
- Expand to support WalletConnect-based initial user login alongside or integrated with Privy.
- Utilize the connection session for onchain transaction sending.
