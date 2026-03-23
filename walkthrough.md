# Location Protocol Flutter App — Walkthrough

## Overview

The app is a thin Flutter integration layer over the `location_protocol` Dart library. All EAS/EIP-712/ABI encoding logic lives in the library — the app's sole responsibility is connecting Privy wallets and user input to the library's interfaces.

**~2,800 lines of custom protocol code deleted. Replaced by the library.**

---

## Architecture

### Module Structure

```
lib/
├── main.dart                    # App entry point, Privy auth wrapper
├── privy/                       # Standalone Privy authentication module (reusable)
│   ├── privy_module.dart        # Barrel export
│   ├── privy_auth_config.dart   # Config model (appId, clientId, login methods, SIWE params)
│   ├── privy_auth_provider.dart # InheritedNotifier — PrivyAuthState exposed to widget tree
│   ├── privy_manager.dart       # Singleton SDK wrapper around Privy Flutter SDK
│   ├── login_modal.dart         # showPrivyLoginModal() entry point
│   ├── widgets/
│   │   ├── login_method_button.dart  # Reusable login button
│   │   └── otp_input_view.dart       # OTP code input widget
│   └── flows/
│       ├── sms_flow.dart        # SMS OTP login
│       ├── email_flow.dart      # Email OTP login
│       ├── oauth_flow.dart      # Google / Twitter / Discord OAuth
│       └── siwe_flow.dart       # Sign-In With Ethereum (SIWE) flow
├── protocol/                    # Bridge: Privy wallets ↔ location_protocol library
│   ├── protocol_module.dart     # Barrel export
│   ├── attestation_service.dart # Orchestrator: offchain sign/verify + onchain calldata builders
│   ├── attestation_service_provider.dart  # InheritedNotifier for AttestationService
│   ├── privy_signer.dart        # PrivySigner — extends Signer, routes via eth_signTypedData_v4
│   ├── external_wallet_signer.dart        # ExternalWalletSigner — paste-signature pattern
│   └── schema_config.dart       # App's SchemaDefinition + LP payload defaults
├── settings/                    # Developer / test configuration
│   ├── settings_service.dart    # SharedPreferences persistence for RPC URL, chainId, private key
│   └── settings_screen.dart     # Settings UI
├── widgets/                     # Shared reusable widgets
│   ├── attestation_result_card.dart   # Displays SignedOffchainAttestation details
│   ├── chain_selector.dart            # Chain dropdown (from ChainConfig.supportedChainIds)
│   ├── private_key_import_dialog.dart # Dialog for entering a hex private key
│   └── external_sign_dialog.dart      # Dialog for pasting an external wallet signature
└── screens/                     # Feature screens
    ├── home_screen.dart          # Auth-gated entry point; routes to all operations
    ├── sign_screen.dart          # Offchain attestation signing (lat/lng/memo)
    ├── verify_screen.dart        # Paste JSON → verify offchain attestation
    ├── onchain_attest_screen.dart  # Build + submit onchain attestation via Privy wallet
    ├── register_schema_screen.dart # Build + submit schema registration via Privy wallet
    └── timestamp_screen.dart    # Build + submit offchain UID timestamping via Privy wallet
```

**No `lib/src/` directory exists.** All custom protocol code has been deleted.

---

## Signer Strategies

The app supports three signing strategies, all implementing `Signer` from the `location_protocol` library:

| Strategy | Class | How it signs |
|---|---|---|
| Privy embedded wallet | `PrivySigner` | Calls `eth_signTypedData_v4` via `wallet.provider.request()` |
| Imported private key | `LocalKeySigner` (from library) | Signs in-process via ECDSA |
| External wallet (MetaMask, etc.) | `ExternalWalletSigner` | Shows typed data JSON; user pastes 65-byte hex signature |

`PrivySigner` is constructed with an injectable `rpcCaller` callback, allowing full unit testing without a real Privy SDK.

---

## Key Flows

### Sign Offchain (Privy wallet or private key)

```
HomeScreen
  → SignScreen
  → AttestationService.signOffchain(lat, lng, memo)
      → AppSchema.buildLPPayload()         # builds LPPayload
      → AppSchema.buildUserData()          # builds schema userData map
      → OffchainSigner.signOffchainAttestation()  # library handles EIP-712
  → AttestationResultCard                  # displays SignedOffchainAttestation
```

### Verify Offchain

```
HomeScreen
  → VerifyScreen
  → User pastes JSON
  → Manual JSON parsing → SignedOffchainAttestation
  → AttestationService.verifyOffchain()
      → OffchainSigner.verifyOffchainAttestation()  # library recovers signer
  → Display VerificationResult (isValid, recoveredAddress)
```

### Attest Onchain (Privy wallet path)

```
HomeScreen
  → OnchainAttestScreen
  → AttestationService.buildAttestCallData(lat, lng, memo)
      → EASClient.buildAttestCallData()    # static — no RPC needed
  → AttestationService.buildTxRequest(callData, contractAddress)
      → TxUtils.buildTxRequest()           # wraps calldata for eth_sendTransaction
  → wallet.provider.request('eth_sendTransaction', [txRequest])
  → Display txHash + block explorer link
```

The same static builder pattern applies to **Register Schema** (`SchemaRegistryClient.buildRegisterCallData`) and **Timestamp** (`EASClient.buildTimestampCallData`).

### Onchain — Private Key Path (dev/test)

```
SettingsScreen → configure RPC URL + private key + chainId
  → AttestationService.attestOnchain(...)
      → DefaultRpcProvider(rpcUrl, privateKeyHex, chainId)
      → EASClient(provider).attest(schema, lpPayload, userData)
      → AttestResult { txHash, uid, blockNumber }
```

---

## Schema Definition

The app schema is defined in `lib/protocol/schema_config.dart` via `SchemaDefinition`:

```
AppSchema.definition = SchemaDefinition(fields: [
  SchemaField(type: 'uint256', name: 'eventTimestamp'),
  SchemaField(type: 'string[]', name: 'recipeType'),
  SchemaField(type: 'bytes[]', name: 'recipePayload'),
  SchemaField(type: 'string[]', name: 'mediaType'),
  SchemaField(type: 'bytes[]', name: 'mediaData'),
  SchemaField(type: 'string',  name: 'memo'),
])
```

LP base fields (`lp_version`, `srs`, `location_type`, `location`) are auto-prepended by the library.

- **Schema UID**: computed via `SchemaUID.compute(AppSchema.definition.schemaString)` — no manual keccak256 required.
- **LP Version**: `LPVersion.current` = `'0.2.0'`
- **SRS**: `'http://www.opengis.net/def/crs/OGC/1.3/CRS84'` (full OGC URI, not the old `EPSG:4326` shorthand)

> **Breaking change**: attestations from the old app (domain version `0.26`, offchain version 1, SRS `EPSG:4326`) are not cross-verifiable with attestations from the redesigned app. This is intentional — the redesigned app aligns with the current `location_protocol` library protocol.

---

## Dependency Summary

| Dependency | Role |
|---|---|
| `location_protocol` (git) | All EAS/EIP-712/ABI encoding, Signer interface, TxUtils, ChainConfig |
| `privy_flutter: ^0.4.0` | Privy auth SDK + embedded wallet |
| `flutter_dotenv: ^5.1.0` | `.env` config loading |
| `shared_preferences: ^2.2.2` | Persistent dev settings (RPC URL, private key, chain) |

`convert` has been removed as it is no longer a direct dependency (used only by deleted code; still available transitively through the library).

---

## Test Coverage

77 unit tests across 5 test directories:

| Directory | What is tested |
|---|---|
| `test/privy/` | `PrivyAuthState`, `PrivyManager` |
| `test/protocol/` | `AttestationService`, `PrivySigner`, `ExternalWalletSigner`, `SchemaConfig`, round-trip sign/verify, schema golden values |
| `test/settings/` | `SettingsService` persistence |
| `test/screens/` | Widget smoke tests for HomeScreen |
| `test/` (root) | Widget smoke test |

All tests pass. `flutter analyze` reports zero issues.
