# Location Protocol Library Migration

## Summary

This document covers the migration from in-app protocol/signing code to the
`DecentralizedGeo/location-protocol-dart` library, and what is left in the app
as app-level concerns.

### What is now in the library (`location-protocol-dart`)

| Responsibility | Library symbol |
|---|---|
| EAS protocol constants (domain name, version, etc.) | `EASConstants` |
| Per-chain contract addresses | `ChainConfig` / `ChainAddresses` |
| Typed schema model | `SchemaDefinition` / `SchemaField` |
| Validated Location Protocol payload | `LPPayload` |
| EIP-712 offchain signing (private-key path) | `OffchainSigner` |
| Verification result type | `VerificationResult` |
| ABI encoding for EAS schemas | `AbiEncoder` (library) |

### What remains in the app (app-only concerns)

| File | Responsibility | Why it stays in the app |
|---|---|---|
| `lib/src/eas/eip712_signer.dart` | EIP-712 signing & signer recovery | Supports pluggable `AttestationSigner` backends (Privy, MetaMask, local key). The library's `OffchainSigner` takes a raw private key and cannot delegate to an external wallet. Full replacement is future work. |
| `lib/src/eas/abi_encoder.dart` | Solidity ABI encoding for the location schema | App-specific schema field layout; will be replaced by the library's `AbiEncoder` once the schema model is aligned. |
| `lib/src/eas/attestation_signer.dart` | Abstract signer interface | App-level abstraction enabling unit testing and multiple wallet backends. |
| `lib/src/eas/local_key_signer.dart` | Raw-key signer for tests and offline use | Test/development utility. |
| `lib/src/eas/privy_signer_adapter.dart` | Privy embedded-wallet signer | Bridges the Privy SDK to `AttestationSigner`; app-specific. |
| `lib/src/eas/external_wallet_signer.dart` | Copy/paste MetaMask signer | App-level UX flow. |
| `lib/src/models/location_attestation.dart` | App attestation data model | App-specific field names; maps to library types on the way in/out. |
| `lib/src/builder/attestation_builder.dart` | Attestation construction helpers | App-level convenience layer. |
| `lib/src/services/` | `LocationProtocolService` interface + `LibraryLocationProtocolService` | Service layer; wires library types to app types. |

## Removed in this migration (issue #8)

### `lib/src/eas/privy_wallet_signer.dart` — deleted

`PrivyWalletSigner` was the original Privy signing integration and had been
marked `@Deprecated` since the introduction of `PrivySignerAdapter`.

**Migration path:**

```dart
// Before (deprecated — removed):
final signer = PrivyWalletSigner(embeddedWallet);

// After:
final signer = PrivySignerAdapter.fromWallet(embeddedWallet);
```

`PrivySignerAdapter` offers the same functionality with an injectable
`EthereumRpcCaller` that enables unit testing without the Privy SDK.

### `lib/src/services/legacy_location_protocol_service.dart` — deleted

`LegacyLocationProtocolService` was a thin wrapper around `EIP712Signer` that
existed solely to support the `useLocationProtocolLibrary` feature flag.  Now
that `LibraryLocationProtocolService` is the only implementation, the separate
legacy class is redundant.

### `lib/src/services/location_protocol_config.dart` — deleted

`LocationProtocolConfig` (and its `useLocationProtocolLibrary` flag) was a
rollout gate between the legacy and library service implementations.  The flag
is no longer needed because there is now a single service implementation
(`LibraryLocationProtocolService`).

**Migration path:**

```dart
// Before:
LocationProtocolProvider(
  config: const LocationProtocolConfig(),  // or useLocationProtocolLibrary: true
  child: myApp,
)

// After:
LocationProtocolProvider(
  child: myApp,
)
```

## Key differences and rationale

### Single service implementation

`LibraryLocationProtocolService` is now the sole concrete implementation of
`LocationProtocolService`.  It currently calls `EIP712Signer` internally while
referencing the library's public types.  The dual-implementation / feature-flag
pattern has been removed because parity between the two paths was confirmed by
the service-layer tests.

### `AttestationSigner` abstraction is preserved

The app's `AttestationSigner` interface is intentionally kept.  The library's
`OffchainSigner` only supports raw private-key signing and cannot delegate to
an external wallet (e.g. Privy embedded wallet, MetaMask).  Replacing
`EIP712Signer` with `OffchainSigner` would require the library to expose an
external-signer API first.

## Future work

1. **Complete library integration in `LibraryLocationProtocolService`** — once
   the `location-protocol-dart` library exposes an `AttestationSigner`-
   compatible signing path, `EIP712Signer` and the app's `abi_encoder.dart` can
   be removed.

2. **Align data models** — `UnsignedLocationAttestation` /
   `OffchainLocationAttestation` should map cleanly to the library's
   `UnsignedAttestation` / `SignedOffchainAttestation`.

## Rollback notes

If the `LibraryLocationProtocolService` produces unexpected results:

1. The removed files are available in git history.  The last commit before this
   migration is tagged in the PR for reference.
2. To restore the feature-flag pattern, reintroduce `LocationProtocolConfig`,
   `LegacyLocationProtocolService`, and restore `LocationProtocolProvider` to
   the pre-migration version from git history.
3. All signing fixtures (`test/fixtures/signing_fixtures.dart`) and baseline
   tests (`test/signing_verification_baseline_test.dart`) are unchanged; they
   can be used to confirm correct behaviour after any rollback.
