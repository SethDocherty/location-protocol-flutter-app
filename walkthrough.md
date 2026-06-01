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
├── protocol/                    # Bridge: Privy wallets + Reown ↔ location_protocol library
│   ├── protocol_module.dart     # Barrel export
│   ├── attestation_service.dart # Orchestrator: offchain sign/verify + onchain calldata builders
│   ├── attestation_service_provider.dart  # InheritedNotifier for AttestationService
│   ├── privy_signer.dart        # PrivySigner — extends Signer, routes via eth_signTypedData_v4
│   ├── external_wallet_signer.dart        # ExternalWalletSigner — bridges Reown WalletConnect sessions
│   ├── eas_scan_service.dart    # GraphQL queries to EAS Scan for schema introspection
│   ├── read_only_eas_rpc_adapter.dart  # RPC read-only queries (timestamps, receipts)
│   └── schema_config.dart       # App's SchemaDefinition + LP payload defaults
├── providers/                   # State management & unified factories
│   ├── app_wallet_provider.dart # Unified signer factory (dispatches Privy/Reown/PrivKey)
│   └── schema_provider.dart     # Dynamic schema persistence + UID computation
├── services/                    # External service integrations
│   ├── reown_service.dart       # WalletConnect AppKit wrapper — eth_signTypedData_v4 + eth_sendTransaction
│   ├── runtime_network_config.dart  # Multi-chain RPC config per selected chainId
│   └── settings_service.dart    # SharedPreferences persistence (RPC URL, chainId, wallet mode)
├── settings/                    # Developer / test configuration
│   └── settings_screen.dart     # Chain/RPC selector, API key configuration
├── widgets/                     # Shared reusable widgets
│   ├── attestation_result_card.dart   # Displays SignedOffchainAttestation details
│   ├── chain_selector.dart            # Chain dropdown (19+ EVM chains supported)
│   ├── private_key_import_dialog.dart # Dialog for entering a hex private key
│   └── networks.dart                  # Reown network definitions
└── screens/                     # Feature screens
    ├── home_screen.dart          # Auth-gated entry point; routes to all operations
    ├── sign_screen.dart          # Offchain attestation signing (lat/lng + dynamic schema fields)
    ├── verify_screen.dart        # Paste JSON → verify offchain attestation
    ├── onchain_attest_screen.dart  # Build + submit onchain attestation (Privy or Reown)
    ├── schema_manager_screen.dart # Schema CRUD, UID generation, onchain registration
    └── timestamp_screen.dart    # Build + submit offchain UID timestamping onchain
```

**No `lib/src/` directory exists.** All custom protocol code has been deleted.

---

## Signer Strategies

The app supports three signing strategies, all implementing `Signer` from the `location_protocol` library. `AppWalletProvider` is the unified factory that instantiates the correct signer based on the active connection type.

| Strategy | Class | How it signs |
|---|---|---|
| Privy embedded wallet | `PrivySigner` | Calls `eth_signTypedData_v4` via `wallet.provider.request()` |
| External wallet via Reown | `ExternalWalletSigner` | Routes through `ReownService.signTypedData()` → WalletConnect session → MetaMask/Wallet |
| Imported private key | `LocalKeySigner` (from library) | Signs in-process via ECDSA |

**Testability:** `PrivySigner` accepts an injectable `EthereumRpcCaller` callback, enabling full unit testing without the Privy SDK. `ExternalWalletSigner` accepts an `ExternalSignCallback`, allowing mocks in tests.

**Transaction dispatch:** Both Privy and Reown paths support sending transactions. Privy routes through the embedded wallet provider; Reown routes through `ReownService.sendTransaction()` which manages chain switching via `ReownAppKitModal`.

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
  → User pastes canonical EAS JSON
  → Package-backed JSON parsing → SignedOffchainAttestation
  → AttestationService.verifyOffchain()
      → OffchainSigner.verifyOffchainAttestation()  # library verifies preserved payload
  → Display VerificationResult (isValid, recoveredAddress)
```

### Attest Onchain (Privy or Reown wallet)

```
HomeScreen
  → OnchainAttestScreen
  → AttestationService.buildAttestCallDataWithUserData(schema, lat, lng, userData)
      → EASClient.buildAttestCallData()    # static — no RPC needed
  → AttestationService.buildTxRequest(callData, contractAddress)
      → TxUtils.buildTxRequest()           # wraps calldata for eth_sendTransaction
  → AppWalletProvider.sendTransaction(txRequest, context)
      → Dispatches to Privy or Reown based on connectionType
      → Reown: syncs chain first, then sends via WalletConnect
  → Display txHash + block explorer link + attestation UID (from event log)
```

The same static builder pattern applies to **Register Schema** (`SchemaRegistryClient.buildRegisterCallData`) and **Timestamp** (`EASClient.buildTimestampCallData`).

### Offchain UID Timestamping (Privy or Reown)

```
HomeScreen
  → TimestampScreen
  → User enters offchain UID
  → AttestationService.buildTimestampCallData(uid)
      → EASClient.buildTimestampCallData()  # static builder
  → AppWalletProvider.sendTransaction(txRequest, context)
  → AttestationService.waitForAttestationUid(txHash)  # polls receipt
  → Display block explorer link
```

### Schema Registration (Privy or Reown)

```
HomeScreen
  → SchemaManagerScreen
  → User modifies schema fields via SchemaProvider
  → AttestationService.buildRegisterSchemaCallData([schema])
  → AppWalletProvider.sendTransaction(txRequest, context)
  → AttestationService.isSchemaUidRegistered(uid)  # confirms onchain
```

### Sign Offchain (All wallet types)

For external wallets (Reown), the flow is identical to Privy:

```
HomeScreen
  → SignScreen
  → AttestationService.signOffchainWithData(schema, lat, lng, userData)
      → OffchainSigner.signOffchainAttestation()  # library handles EIP-712
  → AppWalletProvider.getSigner(context, chainId) returns ExternalWalletSigner
      → ExternalWalletSigner.signTypedData(typedData)
      → ReownService.signTypedData(context, typedData)
      → Returns EIP712Signature
  → AttestationResultCard  # displays SignedOffchainAttestation (same format for all signers)
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
| `location_protocol` (git) | All EAS/EIP-712/ABI encoding, Signer interface, ChainConfig, TxUtils, EASClient, SchemaRegistryClient |
| `privy_flutter: ^0.4.0` | Privy auth SDK + embedded wallet |
| `reown_appkit: ^1.0.0` | WalletConnect AppKit — multi-wallet support (MetaMask, Coinbase, etc.) |
| `flutter_dotenv: ^5.1.0` | `.env` config loading (Privy credentials, Reown project ID) |
| `shared_preferences: ^2.2.2` | Persistent dev settings (RPC URL, private key, chain, last active wallet mode) |

The `on_chain` package (Ethereum utilities) is a transitive dependency via `location_protocol`.

---

## Multi-Chain Support

The app supports 19+ EVM chains (mainnets + testnets) via `ChainConfig` from the `location_protocol` library:

- **Mainnets**: Ethereum, Optimism, Base, Arbitrum One, Arbitrum Nova, Polygon, Celo, Linea, Blast, Scroll, Unichain, Soneium, Ink, Telos
- **Testnets**: Sepolia, Optimism Sepolia, Base Sepolia, Arbitrum Sepolia, Polygon Amoy, Scroll Sepolia, Ink Sepolia

Users select their target chain in SettingsScreen. `RuntimeNetworkConfig` resolves the active chain's EAS contract address, Schema Registry address, and EAS version at runtime. RPC connectivity is either manually entered or auto-resolved via an Infura API key.

---

## Test Coverage

77+ unit tests across 6 test directories:

| Directory | What is tested |
|---|---|
| `test/privy/` | `PrivyAuthState`, `PrivyManager`, login flows |
| `test/protocol/` | `AttestationService`, `PrivySigner`, `ExternalWalletSigner`, `SchemaConfig`, round-trip sign/verify, schema golden values |
| `test/providers/` | `AppWalletProvider` connection type dispatch, `SchemaProvider` persistence |
| `test/services/` | `ReownService` chain sync, read-only RPC queries |
| `test/settings/` | `SettingsService` persistence |
| `test/screens/` | Widget smoke tests for HomeScreen |
| `test/` (root) | Widget smoke test |

All tests pass. `flutter analyze` reports zero issues.
