# PRD: Flutter App Redesign on `location_protocol` Library

**Status:** Draft — Revised (March 2026)

**Upstream dependency satisfied:** The `location_protocol` library has shipped the `Signer` abstract class, `LocalKeySigner`, `OffchainSigner` primary constructor, `EASClient` static builder methods, `TxUtils`, and the full wallet integration pattern. See [PRD: Abstract Signer Interface](prd-signer-interface.md) for the original dependency spec.

## Overview

The Location Protocol Flutter app currently implements ~2,000 lines of custom EAS/EIP-712/ABI encoding logic alongside a working Privy authentication module. This PRD defines the complete redesign of the app to eliminate all custom protocol code and rebuild entirely on the `location_protocol` library. The app's new role is purely as an **integration layer**: connecting Privy wallets to the library's `Signer` interface, defining the app's schema via `SchemaDefinition`, and providing screens for the full attestation lifecycle — offchain signing, onchain attestation, schema registration, verification, and timestamping.

The Privy authentication module is extracted into a standalone, reusable module with zero protocol knowledge. The bridge between Privy and `location_protocol` is a thin `PrivySigner` adapter — the Dart equivalent of `walletClientToSigner()` from the [TypeScript Privy EAS integration](https://github.com/DecentralizedGeo/privy-eas-integration-demo/blob/main/docs/privy-eas-integration.md).

## Goals

- **Zero custom EAS/EIP-712 code in the app** — all protocol logic comes from `location_protocol`
- Extract Privy auth into a reusable module with no protocol dependencies
- Add onchain capabilities: attestation, schema registration, offchain UID timestamping
- Adopt library-native models (`SignedOffchainAttestation`, `VerificationResult`, `AttestResult`, etc.) directly — no app-domain wrappers
- **Configurable Environments** — Provide UI for managing RPC endpoints and developer signing keys

## User Personas

- **Primary:** End users of the Flutter app who authenticate with Privy, sign location attestations, and verify them
- **Secondary:** Developers who may reuse the extracted Privy module or the `PrivySigner` adapter in other apps

## User Stories

### US-001: Sign an offchain attestation with Privy embedded wallet

**As a** user authenticated via Privy, **I want** to create and sign an offchain Location Protocol attestation **so that** I can produce a portable, verifiable spatial record without paying gas.

**Acceptance Criteria:**
- [ ] User enters latitude, longitude, and memo on the Sign screen
- [ ] Tapping "Sign" produces a `SignedOffchainAttestation` (from the library) using the Privy embedded wallet via `eth_signTypedData_v4`
- [ ] The result displays: UID, signer address, signature (v/r/s), location, timestamp, memo
- [ ] The attestation can be verified on the Verify screen
- [ ] `flutter analyze` reports zero issues

### US-002: Sign an offchain attestation with an imported private key

**As a** user without a Privy account, **I want** to sign an attestation using a pasted private key **so that** I can use the app without an authentication provider.

**Acceptance Criteria:**
- [ ] "Sign with Private Key" button is always visible (no auth required)
- [ ] User enters a 64-character hex private key in a dialog
- [ ] Signing uses `LocalKeySigner` from the library — no custom signing code
- [ ] The result is identical in format to a Privy-signed attestation
- [ ] `flutter analyze` reports zero issues

### US-003: Sign an offchain attestation with an external wallet

**As a** user with MetaMask or another external wallet, **I want** to sign an attestation by pasting my signature response **so that** I can use any wallet, not just Privy.

**Acceptance Criteria:**
- [ ] A dialog displays the EIP-712 typed data JSON for the user to sign externally
- [ ] User pastes the 65-byte hex signature
- [ ] The app assembles a valid `SignedOffchainAttestation` from the external signature
- [ ] `flutter analyze` reports zero issues

### US-004: Verify an offchain attestation

**As a** user, **I want** to paste a signed attestation JSON and verify it **so that** I can confirm the signer and data integrity.

**Acceptance Criteria:**
- [ ] User pastes JSON (EAS offchain format or the library's model format)
- [ ] App calls `OffchainSigner.verifyOffchainAttestation()` from the library
- [ ] Display shows: valid/invalid, recovered address, claimed signer, location, timestamp, memo
- [ ] Tampered attestations show as invalid with a reason
- [ ] `flutter analyze` reports zero issues

### US-005: Create an onchain attestation

**As an** authenticated user, **I want** to submit a location attestation onchain **so that** it is permanently anchored on the blockchain.

**Acceptance Criteria:**
- [ ] Onchain Attest screen provides the same input fields as Sign screen (lat, lng, memo)
- [ ] User selects a target chain from a dropdown (populated from `ChainConfig.supportedChainIds`)
- [ ] Submitting uses `EASClient.buildAttestCallData()` + `TxUtils.buildTxRequest()` via the Privy wallet (`eth_sendTransaction`), or `EASClient.attest()` for private-key flows
- [ ] Display shows `AttestResult`: txHash, UID, block number
- [ ] The schema must already be registered (error message if not)
- [ ] `flutter analyze` reports zero issues

### US-006: Register a schema onchain

**As an** authenticated user, **I want** to register the app's EAS schema on a target chain **so that** I can create onchain attestations against it.

**Acceptance Criteria:**
- [ ] Register Schema screen shows the full schema string and computed UID
- [ ] User selects a target chain
- [ ] Submitting uses `SchemaRegistryClient.buildRegisterCallData()` + `TxUtils.buildTxRequest()` via the Privy wallet, or `SchemaRegistryClient.register()` for private-key flows
- [ ] Shows `RegisterResult` including `alreadyExisted` indicator
- [ ] `flutter analyze` reports zero issues

### US-007: Timestamp an offchain UID onchain

**As a** user with an offchain attestation, **I want** to anchor its UID onchain **so that** I have immutable proof of existence without storing the full payload.

**Acceptance Criteria:**
- [ ] Timestamp screen accepts an offchain UID (0x-prefixed hex)
- [ ] Submitting uses `EASClient.buildTimestampCallData()` + `TxUtils.buildTxRequest()` via the Privy wallet, or `EASClient.timestamp()` for private-key flows
- [ ] Shows `TimestampResult`: txHash, UID, timestamp
- [ ] `flutter analyze` reports zero issues

### US-008: Login and manage wallet via Privy

**As a** user, **I want** to authenticate using email, SMS, Google, Twitter, Discord, or SIWE **so that** I can create an embedded wallet without managing keys.

**Acceptance Criteria:**
- [ ] All 6 login methods work (SMS, Email, Google, Twitter, Discord, SIWE)
- [ ] Embedded wallet is auto-created on first login
- [ ] Wallet address is displayed on the home screen
- [ ] Logout clears auth state
- [ ] The Privy module has zero imports from `lib/protocol/` or `location_protocol`
- [ ] `flutter analyze` reports zero issues

### US-009: Configure Developer Settings

**As a** developer/tester, **I want** to configure RPC URLs and test private keys **so that** I can test onchain operations across different networks without rebuilding the app.

**Acceptance Criteria:**
- [ ] Settings screen allows entry of RPC URL and Private Key
- [ ] Values are persisted across app restarts using `SharedPreferences`
- [ ] `AttestationService` uses these values when in "Private Key" mode
- [ ] `flutter analyze` reports zero issues

## Functional Requirements

### Protocol Bridge

- **FR-1:** The app MUST implement a `PrivySigner` class that **extends** the library's `Signer` abstract class (use `extends`, not `implements`, to inherit the default `signTypedData` body — see [Signer API reference](https://github.com/DecentralizedGeo/location-protocol-dart/blob/main/docs/guides/reference-api.md#signer)):
  - Constructor accepts a Privy `EmbeddedEthereumWallet`
  - `signTypedData(Map<String, dynamic>)` overrides the default: calls `wallet.provider.request('eth_signTypedData_v4', [address, jsonEncode(typedData)])` and parses the hex response via `EIP712Signature.fromHex(rawSig)`
  - `signDigest(Uint8List)` throws `UnsupportedError` — wallet signers route exclusively through `signTypedData`; this method is never called by `OffchainSigner` (see [Concepts: Why signTypedData rather than signDigest](https://github.com/DecentralizedGeo/location-protocol-dart/blob/main/docs/guides/explanation-concepts.md#7-the-signer-interface-and-wallet-integration))
  - `address` returns the wallet's Ethereum address
  - The library normalizes `v` to 27/28 inside `OffchainSigner.signOffchainAttestation()`, so `PrivySigner` does not need to handle `v` normalization

- **FR-2:** The app MUST implement an `ExternalWalletSigner` class that **extends** `Signer`:
  - `signTypedData(Map)` shows a dialog with the typed data JSON, accepts a pasted 65-byte hex signature, returns `EIP712Signature.fromHex(pastedSig)`
  - `signDigest()` throws `UnsupportedError` (external wallets must use typed data)
  - `address` is provided at construction time

- **FR-3:** The app MUST define its schema via `SchemaDefinition(fields: [...])` from the library:
  ```
  SchemaField(type: 'uint256', name: 'eventTimestamp')
  SchemaField(type: 'string[]', name: 'recipeType')
  SchemaField(type: 'bytes[]', name: 'recipePayload')
  SchemaField(type: 'string[]', name: 'mediaType')
  SchemaField(type: 'bytes[]', name: 'mediaData')
  SchemaField(type: 'string', name: 'memo')
  ```
  LP base fields (`lp_version`, `srs`, `location_type`, `location`) are auto-prepended by the library.

- **FR-4:** The app MUST provide an `AttestationService` class that orchestrates all protocol operations. The service supports two onchain paths depending on the signer type:

  **Offchain operations (all signer types):**
  - `signOffchain({required double lat, required double lng, required String memo, ...})` → `Future<SignedOffchainAttestation>` — uses `OffchainSigner.signOffchainAttestation()`
  - `verifyOffchain(SignedOffchainAttestation)` → `VerificationResult` (synchronous — not a `Future`) — uses `OffchainSigner.verifyOffchainAttestation()`

  **Onchain operations — Privy wallet path (primary):**
  Uses the library's static builder pipeline (no `RpcProvider` instantiation needed). See [How to build wallet-based onchain transactions](https://github.com/DecentralizedGeo/location-protocol-dart/blob/main/docs/guides/how-to-wallet-onchain-transactions.md):
  1. Build ABI-encoded calldata offline via static methods: `EASClient.buildAttestCallData(...)`, `EASClient.buildTimestampCallData(uid)`, `SchemaRegistryClient.buildRegisterCallData(schema)`
  2. Wrap with `TxUtils.buildTxRequest(to: contractAddress, data: callData, from: walletAddress)` to produce a wallet-friendly `Map<String, dynamic>`
  3. Submit via `wallet.provider.request('eth_sendTransaction', [txRequest])`

  **Onchain operations — Private-key path (testing/dev):**
  Uses `EASClient` and `SchemaRegistryClient` instance methods, which require a `DefaultRpcProvider(rpcUrl:, privateKeyHex:, chainId:)`:
  - `attestOnchain(...)` → `Future<AttestResult>` via `EASClient.attest()`
  - `registerSchema()` → `Future<RegisterResult>` via `SchemaRegistryClient.register()`
  - `timestampOffchain(String uid)` → `Future<TimestampResult>` via `EASClient.timestamp()`

- **FR-5:** `AttestationService` MUST create `LPPayload` objects from user input:
  - `lpVersion`: from `LPVersion.current` (`0.2.0`)
  - `srs`: `'http://www.opengis.net/def/crs/OGC/1.3/CRS84'`
  - `locationType`: `'geojson-point'`
  - `location`: `{'type': 'Point', 'coordinates': [lng, lat]}`

- **FR-6:** `AttestationService` MUST construct the `userData` map matching the schema fields:
  - `'eventTimestamp'`: `BigInt` (Unix seconds)
  - `'recipeType'`: `List<String>` (default empty)
  - `'recipePayload'`: `List<Uint8List>` (default empty)
  - `'mediaType'`: `List<String>` (default empty)
  - `'mediaData'`: `List<Uint8List>` (default empty)
  - `'memo'`: `String`

### Settings module

- **FR-14:** The app MUST implement a `SettingsService` using `SharedPreferences` to manage:
  - `rpcUrl`: user-configured Ethereum RPC endpoint
  - `privateKey`: user-configured developer signing key (not for production use)
  - `chainId`: target chain for dev operations

### Privy Module

- **FR-7:** The Privy auth module MUST be fully self-contained under `lib/privy/`:
  - No imports from `lib/protocol/`, `lib/screens/`, or `location_protocol`
  - Only depends on `privy_flutter`, `flutter_dotenv`, and Flutter SDK
  - Exports: `PrivyAuthProvider`, `PrivyAuthState`, `PrivyAuthConfig`, `showPrivyLoginModal`, `PrivyManager`, `LoginMethod`

- **FR-8:** All 6 login flows (SMS, Email, Google, Twitter, Discord, SIWE) MUST be preserved from the current implementation.

- **FR-9:** `PrivyAuthState` MUST expose: `isReady`, `isAuthenticated`, `user`, `wallet` (`EmbeddedEthereumWallet?`), `walletAddress` (`String?`), `logout()`.

### Screens

- **FR-10:** `HomeScreen` MUST be auth-gated and show:
  - When unauthenticated: login button + "Sign with Private Key" button
  - When authenticated: wallet address, buttons for all 5 operations (Sign Offchain, Attest Onchain, Register Schema, Verify, Timestamp), plus Sign with Private Key and Sign with External Wallet, and a **Settings** link

- **FR-11:** All screens MUST use library-native models directly (`SignedOffchainAttestation`, `VerificationResult`, `AttestResult`, `RegisterResult`, `TimestampResult`). No app-specific attestation model classes.

- **FR-12:** The `VerifyScreen` MUST accept pasted JSON and reconstruct a `SignedOffchainAttestation` for verification. This requires JSON deserialization logic (implemented within the app's script layer).

### Code Removal

- **FR-13:** The following files MUST be deleted (custom protocol code replaced by the library):
  - `lib/src/eas/eip712_signer.dart` (~1031 lines)
  - `lib/src/eas/abi_encoder.dart`
  - `lib/src/eas/schema_config.dart`
  - `lib/src/eas/attestation_signer.dart`
  - `lib/src/eas/ecdsa_signature.dart`
  - `lib/src/eas/local_key_signer.dart`
  - `lib/src/eas/privy_signer_adapter.dart`
  - `lib/src/eas/external_wallet_signer.dart`
  - `lib/src/eas/external_sign_dialog.dart`
  - `lib/src/eas/private_key_import_dialog.dart`
  - `lib/src/models/location_attestation.dart`
  - `lib/src/builder/attestation_builder.dart`
  - `lib/src/services/location_protocol_service.dart`
  - `lib/src/services/library_location_protocol_service.dart`
  - `lib/src/services/location_protocol_provider.dart`

## Non-Functional Requirements

- **Performance:** Offchain signing latency (user tap → result displayed) MUST be under 2 seconds on mid-range hardware.
- **Security:** Raw private keys entered in the import dialog MUST NOT be persisted to disk or logged unless explicitly stored by the user in the Settings module. Privy wallet keys never leave the Privy SDK enclave.
- **Testability:** `PrivySigner` and `ExternalWalletSigner` MUST accept an injected request callable (`Future<String> Function(String method, List<dynamic> params)`) for unit testing without a real Privy SDK or wallet. This replaces the wallet SDK's `provider.request` call, allowing tests to return canned signature responses.

## Out of Scope

- **Custom location types beyond `geojson-point`** — the app UI only supports lat/lng input. The library supports 9 types, but additional UI surfaces are a separate feature.
- **Attestation persistence / history** — the app does not store signed attestations. Copy/paste is the persistence mechanism.
- **Onchain attestation gas estimation or payment UX** — the app submits transactions and shows results but does not estimate or display gas costs.
- **Multi-chain wallet switching UI** — users select a chain from a dropdown, but the app does not prompt for chain switching in the wallet itself.
- **Updating the library's `SignedOffchainAttestation` to support JSON serialization** — the app handles JSON parsing/construction itself for the Verify screen.
- **Publishing the Privy module as a separate pub.dev package** — it's extracted within the app for now.
- **Backward compatibility with current-app attestations** — the redesigned app adopts EAS domain version `1.0.0` (current app uses `0.26`) and offchain attestation version 2 with salt (current app uses version 1 without salt). These are intentional protocol alignment changes. Attestations from the old and new app are not cross-verifiable. See [Breaking Changes](#breaking-changes-vs-current-app) below.

## Technical Considerations

### New File Structure

> [!NOTE]
> The file structure below was refined and better defined during the creation of the implementation plan to ensure clean separation of concerns and reusability.

```
lib/
├── main.dart                               # Rewired: PrivyAuthProvider + AttestationServiceProvider
├── privy/                                  # Standalone auth module
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
│   └── attestation_service_provider.dart
├── settings/                               # NEW: Dev/test config
│   ├── settings_service.dart               # SharedPreferences wrapper
│   └── settings_screen.dart                # RPC URL, private key config UI
├── screens/
│   ├── home_screen.dart
│   ├── sign_screen.dart
│   ├── verify_screen.dart
│   ├── onchain_attest_screen.dart          # NEW
│   ├── register_schema_screen.dart         # NEW
│   └── timestamp_screen.dart           # NEW
└── widgets/
    ├── attestation_result_card.dart        # NEW: Reusable result display
    ├── chain_selector.dart                 # NEW: Chain configuration dropdown
    ├── private_key_import_dialog.dart
    └── external_sign_dialog.dart
```

### Dependencies

| Dependency | Purpose | Change |
|------------|---------|--------|
| `location_protocol` (git) | All EAS/EIP-712/ABI logic + Signer, TxUtils, static builders | Update git ref to Signer-enabled commit |
| `privy_flutter: ^0.4.0` | Auth + embedded wallets | No change |
| `flutter_dotenv: ^5.1.0` | Environment config | No change |
| `shared_preferences: ^2.2.2` | Persistent dev settings | **NEW** |
| `convert: ^3.1.1` | Hex encoding | No change |

### Dependencies to Evaluate for Removal

- Direct imports of `on_chain`, `blockchain_utils`, or `web3dart` from app code should be eliminated. If only used by the deleted `lib/src/eas/` files, they are no longer needed as direct dependencies (the library brings them transitively).

### Onchain Architecture: Two Paths

The library provides two complementary mechanisms for onchain operations, each suited to a different signing context:

**1. Static builder pipeline (for Privy wallets — primary path)**

The library's static methods produce ABI-encoded calldata without any RPC connection. `TxUtils.buildTxRequest()` wraps the calldata into a wallet-friendly `Map<String, dynamic>`. The app submits via the Privy SDK. See the [wallet onchain transactions guide](https://github.com/DecentralizedGeo/location-protocol-dart/blob/main/docs/guides/how-to-wallet-onchain-transactions.md).

```
EASClient.buildAttestCallData(schema:, lpPayload:, userData:)
  → Uint8List callData

TxUtils.buildTxRequest(to: easAddress, data: callData, from: walletAddress)
  → Map<String, dynamic> txRequest

wallet.provider.request('eth_sendTransaction', [txRequest])
  → String txHash
```

The same pipeline applies to schema registration (`SchemaRegistryClient.buildRegisterCallData`) and timestamping (`EASClient.buildTimestampCallData`). Contract addresses are resolved via `ChainConfig.forChainId(chainId)`.

**2. Instance methods (for private-key dev/test path)**

`EASClient` and `SchemaRegistryClient` instance methods manage the full lifecycle (ABI encoding → transaction signing → broadcasting → receipt polling) internally. They require a `DefaultRpcProvider` with a raw private key and RPC URL (sourced from the `Settings` module):

```
DefaultRpcProvider(rpcUrl: '...', privateKeyHex: '...', chainId: 11155111)
  → RpcProvider

EASClient(provider: rpcProvider).attest(schema:, lpPayload:, userData:)
  → AttestResult { txHash, uid, blockNumber }
```

### Breaking Changes vs Current App

The redesigned app intentionally breaks backward compatibility with attestations produced by the current app. These changes align the app with the `location_protocol` library's protocol implementation:

| Aspect | Current App | Redesigned App | Impact |
|--------|-------------|----------------|--------|
| EAS domain version | `"0.26"` | `"1.0.0"` | Different EIP-712 domain separator → different signatures |
| Offchain attestation version | 1 (no salt) | 2 (with 32-byte CSPRNG salt) | Different UID computation scheme |
| SRS value | `"EPSG:4326"` (shorthand) | `"http://www.opengis.net/def/crs/OGC/1.3/CRS84"` (full URI) | Different ABI encoding → different data payload |

As a result, old-app attestations cannot be verified by the new app, and new-app attestations cannot be verified by the old app. This is expected and acceptable — the old protocol parameters were non-standard.

### Risks

- **Privy `eth_signTypedData_v4` compatibility:** The EIP-712 typed data JSON map produced by the library's `OffchainSigner.buildOffchainTypedDataJson()` must match the format Privy's embedded wallet expects. The Privy Flutter SDK may have specific requirements for key ordering, type encoding, or `chainId` format (number vs. hex). All `uint*` values are emitted as decimal strings and all `bytes*`/`address` values as `0x`-prefixed hex strings — this is the standard EIP-712 JSON format, but must be integration tested.
<[!NOTE] Tested and verified against standard EIP-712 JSON format.

- **Schema parity:** The 10-field schema must produce identical ABI encoding and schema UID via the library as it does via the current custom code. This is a golden-value verification test (acknowledging the SRS change will produce a different UID than the old app — parity is verified against the library's own expected values).
<[!NOTE] SRS change acknowledged as causing a deterministic UID shift.

- **Onchain operations require gas:** The app currently only does offchain signing (zero gas). Onchain features need a wallet with funds. This is a UX complexity increase.
<[!NOTE] Addressed via the integration of `ChainSelector` and `Settings` module for dev network testing.

- **Transaction receipt handling:** After submitting via `eth_sendTransaction`, the app needs the txHash to display results. Extracting the UID from event logs (for onchain attestations) requires receipt parsing, which is handled differently depending on the path — see Open Question 5.
<[!NOTE] Post-submission UX will show txHash immediately; full receipt polling is deferred (YAGNI).

### Migration Testing

To verify correct operation of the redesigned app:
1. Sign an offchain attestation with the redesigned app using a known private key via `LocalKeySigner`
2. Verify the attestation round-trips successfully via `OffchainSigner.verifyOffchainAttestation()`
3. Confirm the schema UID matches `SchemaUID.compute(schema)` for the app's `SchemaDefinition`
4. Confirm the `LPPayload` fields (`lpVersion`, `srs`, `locationType`, `location`) are correctly ABI-encoded by the library

## Success Metrics

- **Primary:** Zero lines of custom EAS, EIP-712, or ABI encoding code in the app — all protocol logic sourced from `location_protocol`
- **Secondary:** All current functionality preserved (Privy auth, 3 signer types, offchain sign, verify) plus 3 new capabilities (onchain attest, schema registration, timestamping)
- **Tertiary:** Privy module is fully decoupled — can be moved to a separate package with no code changes

## Open Questions

1.  **Onchain RPC URL configuration:** Where should users configure the RPC endpoint for the private-key dev/test path? Environment variable (`.env`), in-app settings, or hardcoded per chain?
    -   **Answer:** The app will use a mixed approach: sensitive/default environment variables via `.env` for bootstrapping, and a dedicated `SettingsScreen`/`SettingsService` (persisted via `SharedPreferences`) for runtime configuration of RPC URLs and private keys.

2. ~~**Onchain transaction signing with Privy:**~~ **Resolved.** The library provides the static builder pipeline: `EASClient.buildAttestCallData()` → `TxUtils.buildTxRequest()` → `wallet.provider.request('eth_sendTransaction', [txRequest])`. See [How to build wallet-based onchain transactions](https://github.com/DecentralizedGeo/location-protocol-dart/blob/main/docs/guides/how-to-wallet-onchain-transactions.md).
    -   **Answer:** **Resolved.** The library provides the static builder pipeline: `EASClient.buildAttestCallData()` → `TxUtils.buildTxRequest()` → `wallet.provider.request('eth_sendTransaction', [txRequest])`.

3.  **JSON deserialization for VerifyScreen:** Should the app define its own JSON → `SignedOffchainAttestation` parsing, or should this be contributed upstream?
    -   **Answer:** The app will implement custom JSON parsing within the `VerifyScreen` logic for now to maintain isolation. Upstream contribution is deferred until the pattern is proven.

4. **Schema versioning:** If the upstream library's `LPVersion.current` changes, attestations with the old version will have different UIDs. Should the app pin a specific version or always use `current`? (`LPVersion.current` is currently `"1.0.0"`.)
    -   **Answer:** Always use `LPVersion.current` (`0.2.0`).

5. **Transaction receipt polling for Privy wallet path:** How to handle confirmation after receipt of txHash? After submitting an onchain transaction via `wallet.provider.request('eth_sendTransaction', [txRequest])`, the app receives a txHash but needs to wait for confirmation and extract the UID/timestamp from event logs to display `AttestResult`/`TimestampResult`. Options to investigate during implementation:
   - Use Privy SDK's own transaction confirmation callbacks (if available)
   - Instantiate a read-only `DefaultRpcProvider` solely for `waitForReceipt(txHash)` + log parsing (requires an RPC URL)
   - Show txHash immediately and let users verify on a block explorer (deferred UX)

   -   **Answer:** (A) Defer complex receipt polling (YAGNI). Show the txHash immediately with a link to a block explorer.

6. **Start Over vs Iterative Refactor:** Should the redesign be implemented as a complete rewrite in a new branch (`start-over`), or as an iterative refactor on the existing codebase (`iterative-refactor`)? (A) After reviewing the PRD and existing code base finds that it's more efficient to start with a clean slate given the extensive code removal and architectural changes, defer to a complete rewrite while migrating components and features that can be preserved (or are essential for continuity, like the Privy auth flows). The new code can be developed in a `start-over` branch and then merged back into main when complete, rather than trying to incrementally refactor the existing code. This approach minimizes merge conflicts and allows for a more flexible redesign process.

    -   **Answer:** (A) A "start-over" approach in a dedicated branch was selected to ensure the clean removal of legacy protocol code while migrating essential auth flows.
