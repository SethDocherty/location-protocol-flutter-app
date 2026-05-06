# App Audit: `location_protocol` Compatibility Review Against Upstream `main`

## Purpose
This document audits every direct use of `package:location_protocol/location_protocol.dart` in the Flutter app and identifies the edits required to keep the app compliant with the latest `location-protocol-dart` code and guidance on GitHub `main`.

This is a reference-style migration audit. It is intentionally focused on:
- where the package is used
- what each usage is responsible for
- what appears compliant already
- what should be reviewed carefully
- what should likely be changed first to keep the app working

## Audit Basis
Target upstream baseline:
- `location_protocol` GitHub `main`
- upstream README
- `doc/guides/tutorial-wallet-signer.md`
- `doc/guides/explanation-concepts.md#7-the-signer-interface-and-wallet-integration`
- `doc/guides/how-to-wallet-onchain-transactions.md`

Local reference context:
- `docs/spec/plans/prd-app-redesign.md`
- `docs/spec/plans/prd-signer-interface.md`
- `docs/spec/2026-03-24-schema-manager-design.md`

Out of scope for this audit:
- current git dependency pinning / publication timing for `location_protocol`

## Executive Summary
The app is already aligned with the latest upstream library in one important way: it treats `location_protocol` as the protocol source of truth and keeps wallet and Flutter concerns in the app layer.

The main compatibility risks are at the boundaries:
1. dynamic schema input parsing for `bytes[]`
2. manual JSON serialization and deserialization of `SignedOffchainAttestation`
3. wallet-SDK-specific `Signer` request formatting
4. custom onchain polling and RPC parsing

The highest-confidence implementation issue is that the UI currently parses all array fields as `List<String>`, even though the app schema defines `bytes[]` fields that should become `List<Uint8List>` before signing or onchain ABI encoding.

---

## Direct Usage Inventory

| File | Key upstream symbols | Responsibility boundary | Audit status |
| --- | --- | --- | --- |
| `lib/protocol/attestation_service.dart` | `Signer`, `OffchainSigner`, `SignedOffchainAttestation`, `VerificationResult`, `EASClient`, `SchemaRegistryClient`, `TxUtils`, `ChainConfig` | Primary protocol bridge | Review required |
| `lib/protocol/schema_config.dart` | `SchemaDefinition`, `SchemaField`, `SchemaUID`, `LPPayload`, `LPVersion` | App schema and LP payload defaults | Review required |
| `lib/protocol/privy_signer.dart` | `Signer`, `EIP712Signature` | Wallet signer boundary | Review required |
| `lib/protocol/external_wallet_signer.dart` | `Signer`, `EIP712Signature` | Wallet signer boundary | Likely compliant |
| `lib/providers/app_wallet_provider.dart` | `Signer`, `LocalKeySigner` | Wallet selection / signer construction | Likely compliant |
| `lib/providers/schema_provider.dart` | `SchemaDefinition`, `SchemaField`, `SchemaUID` | Dynamic schema state and persistence | Likely compliant |
| `lib/screens/home_screen.dart` | `LocalKeySigner` | Navigation / service bootstrap | Likely compliant |
| `lib/screens/sign_screen.dart` | `SchemaDefinition`, `SchemaField`, `SignedOffchainAttestation` | User input boundary for offchain signing | Probable edits required |
| `lib/screens/onchain_attest_screen.dart` | `SchemaDefinition`, `SchemaField` | User input boundary for onchain attest | Probable edits required |
| `lib/screens/verify_screen.dart` | `SignedOffchainAttestation`, `VerificationResult`, `EIP712Signature` | Display + manual decode boundary | Probable edits required |
| `lib/screens/schema_manager_screen.dart` | `SchemaField` | Schema editing / EAS Scan import boundary | Likely compliant |
| `lib/widgets/chain_selector.dart` | `ChainConfig` | Chain selection UI | Likely compliant |
| `lib/widgets/attestation_result_card.dart` | `SignedOffchainAttestation` | Display + manual encode boundary | Probable edits required |
| `lib/services/reown_service.dart` | `EIP712Signature` | External wallet RPC boundary | Review required |

### File-by-file Notes

#### `lib/protocol/attestation_service.dart`
Owns the main application bridge to the library.

Current responsibilities:
- constructs `OffchainSigner`
- signs and verifies offchain attestations
- builds static calldata for wallet-driven onchain operations
- wraps calldata with `TxUtils.buildTxRequest()`
- performs schema / timestamp / receipt lookups through raw RPC calls

Upstream alignment:
- aligned with the documented wallet flow: static calldata builder -> `TxUtils.buildTxRequest()` -> wallet submission
- aligned with `Signer`-based offchain flow

Concern:
- app-specific transaction augmentation and custom RPC parsing make this file more brittle than the core library-backed path

#### `lib/protocol/schema_config.dart`
Defines the app default schema and LP payload defaults.

Current responsibilities:
- defines app user fields
- computes schema UID via `SchemaUID.compute(...)`
- builds `LPPayload`
- builds default `userData`

Upstream alignment:
- consistent with the library model that LP base fields are auto-prepended by `SchemaDefinition`
- consistent with local computation of `SchemaUID`

Concern:
- `recipePayload` and `mediaData` are defined as `bytes[]`, which must be preserved end-to-end through UI parsing and ABI encoding
- `LPVersion.current` should be retained, but any semantic drift in upstream constants should be checked during implementation

#### `lib/protocol/privy_signer.dart`
Implements a wallet-backed `Signer` for Privy.

Current responsibilities:
- overrides `signTypedData(...)`
- throws from `signDigest(...)`
- parses raw RPC signatures into `EIP712Signature`

Upstream alignment:
- strongly aligned with upstream wallet signer guidance: wallet signers override `signTypedData()` and leave `signDigest()` unreachable
- correctly relies on library-side `v` normalization in `OffchainSigner`

Concern:
- the `primaryType` -> `primary_type` remap is a Privy-specific shim, not an upstream `location_protocol` requirement
- map params are JSON-encoded before RPC submission; this must be validated against current Privy SDK behavior whenever the SDK or typed-data shape changes

#### `lib/protocol/external_wallet_signer.dart`
Thin external wallet `Signer` adapter.

Current responsibilities:
- delegates `signTypedData(...)` to app-provided callback
- throws from `signDigest(...)`

Upstream alignment:
- matches the documented wallet signer pattern cleanly

Concern:
- low concern in isolation; behavior mainly depends on the callback implementation supplied by the app

#### `lib/providers/app_wallet_provider.dart`
Constructs `Signer` implementations based on current wallet mode.

Current responsibilities:
- creates `PrivySigner`, `ExternalWalletSigner`, or `LocalKeySigner`
- routes wallet transaction submission

Upstream alignment:
- consistent with the library design that callers provide the `Signer`

Concern:
- low concern; main sensitivity is downstream wallet transport behavior rather than the provider itself

#### `lib/providers/schema_provider.dart`
Owns runtime schema state.

Current responsibilities:
- persists user fields
- rebuilds `SchemaDefinition`
- recomputes `SchemaUID`

Upstream alignment:
- aligned with current library expectations

Concern:
- low concern; main risk is if UI and schema field types drift apart

#### `lib/screens/home_screen.dart`
Builds service instances for navigation targets.

Current responsibilities:
- creates `AttestationService`
- supplies dummy `LocalKeySigner` for verify-only flow

Upstream alignment:
- low-risk app composition layer

Concern:
- low concern; no direct protocol transformation beyond service construction

#### `lib/screens/sign_screen.dart`
Collects dynamic input for offchain signing.

Current responsibilities:
- renders fields based on `SchemaField`
- builds `userData` map from text input

Concern:
- currently parses every `*[]` field as `List<String>`
- this is incompatible with app-defined `bytes[]` fields and is the clearest likely runtime bug in the current integration

#### `lib/screens/onchain_attest_screen.dart`
Collects dynamic input for onchain attestations.

Current responsibilities:
- renders fields based on `SchemaField`
- builds `userData` map from text input
- passes the resulting payload into library calldata builders

Concern:
- same `bytes[]` parsing issue as `SignScreen`
- onchain ABI encoding is less forgiving than display logic, so malformed `bytes[]` values are likely to surface here quickly

#### `lib/screens/verify_screen.dart`
Parses pasted JSON and reconstructs `SignedOffchainAttestation`.

Current responsibilities:
- manual JSON decode
- manual `Uint8List` reconstruction from hex
- manual `EIP712Signature` reconstruction

Concern:
- upstream docs do not establish a stable public JSON wire contract for `SignedOffchainAttestation`
- any upstream model drift can break verification input compatibility even if signing still works

#### `lib/screens/schema_manager_screen.dart`
Displays and edits user fields, imports schemas from EAS Scan.

Current responsibilities:
- parses schema strings
- filters LP base fields
- manages schema registration flow

Upstream alignment:
- generally aligned with `SchemaField` / `SchemaDefinition` usage

Concern:
- low concern; no obvious latest-API mismatch found in the current review

#### `lib/widgets/chain_selector.dart`
Displays chain choices from `ChainConfig`.

Upstream alignment:
- directly aligned with upstream chain configuration usage

Concern:
- low concern

#### `lib/widgets/attestation_result_card.dart`
Displays signed attestation fields and exports JSON.

Current responsibilities:
- renders `SignedOffchainAttestation`
- manually serializes `data`, `signature`, and other fields to JSON

Concern:
- shares the same manual serialization fragility as `VerifyScreen`
- any change in upstream field types or expectations can break copy/paste round-tripping

#### `lib/services/reown_service.dart`
Bridges typed data and transaction requests to the Reown wallet SDK.

Current responsibilities:
- submits `eth_signTypedData_v4`
- submits `eth_sendTransaction`
- parses returned signatures into `EIP712Signature`

Upstream alignment:
- consistent with the documented wallet path in shape

Concern:
- transport assumptions must be revalidated against the Reown SDK when the app update is implemented

---

## Upstream Guidance Alignment

### 1. `Signer` interface expectations
Upstream guidance confirms the intended split:
- the library owns EIP-712 typed data construction, UID derivation, and verification
- the caller supplies a `Signer`
- wallet-backed signers override `signTypedData(...)`
- wallet-backed signers do not use `signDigest(...)`
- `OffchainSigner` normalizes `v`

Local alignment:
- `lib/protocol/privy_signer.dart` is aligned conceptually
- `lib/protocol/external_wallet_signer.dart` is aligned conceptually
- `lib/providers/app_wallet_provider.dart` correctly treats signer selection as an app concern

### 2. Wallet-based onchain transactions
Upstream guidance for wallets is:
1. build calldata offline through static helpers
2. wrap calldata with `TxUtils.buildTxRequest()`
3. pass the resulting map to the wallet SDK

Local alignment:
- `lib/protocol/attestation_service.dart` follows this pattern for attestation, schema registration, and timestamping
- `lib/providers/app_wallet_provider.dart` and `lib/services/reown_service.dart` complete the wallet submission step

### 3. Schema composition and UID handling
Upstream guidance confirms:
- LP base fields are auto-prepended
- application code should only define business fields
- schema UID is computed locally

Local alignment:
- `lib/protocol/schema_config.dart` matches this shape
- `lib/providers/schema_provider.dart` matches this shape
- `lib/screens/schema_manager_screen.dart` correctly hides LP base fields from editable imported schemas

### 4. LP payload construction
Upstream guidance confirms:
- `LPPayload` validates at construction time
- location data should already be normalized before signing

Local alignment:
- `lib/protocol/schema_config.dart` constructs `LPPayload` centrally

Review note:
- `LPVersion.current` is the correct app-level choice unless upstream changes its semantics; keep it under review but not as a primary concern

---

## Probable Edits Required

### A. Fix dynamic `bytes[]` handling
Affected files:
- `lib/screens/sign_screen.dart`
- `lib/screens/onchain_attest_screen.dart`
- `lib/protocol/schema_config.dart` (source schema definition)
- `lib/providers/schema_provider.dart` (dynamic field source)

Problem:
- current UI parsing treats all array fields as comma-separated strings
- app schema defines `recipePayload` and `mediaData` as `bytes[]`
- library signing and ABI encoding expect those values to be provided as `List<Uint8List>` rather than `List<String>`

Recommended edits:
- introduce type-aware parsing by `SchemaField.type`
- treat `bytes[]` separately from `string[]`
- define one accepted user input convention for `bytes[]` values, preferably comma-separated hex strings
- convert each item into `Uint8List` before calling `signOffchainWithData(...)` or `buildAttestCallDataWithUserData(...)`
- reject malformed byte input before it reaches the library layer

Why this matters:
- this is the most likely current source of runtime signing / encoding failures

### B. Harden `SignedOffchainAttestation` JSON round-tripping
Affected files:
- `lib/widgets/attestation_result_card.dart`
- `lib/screens/verify_screen.dart`

Problem:
- the app owns both serialization and deserialization for `SignedOffchainAttestation`
- upstream docs do not define a stable public JSON contract for the model

Recommended edits:
- explicitly document the app JSON format as an app-owned format
- centralize serialization and deserialization logic into one shared utility instead of duplicating assumptions in two widgets/screens
- verify every field type against the current upstream model before finalizing the utility
- add tests covering app-exported JSON -> app-imported verification

Why this matters:
- otherwise copy/paste verification can silently drift out of sync with the library model

---

## Review Required Before Editing

### C. Revalidate Privy typed-data transport behavior
Affected file:
- `lib/protocol/privy_signer.dart`

Review focus:
- whether `primaryType` still must be remapped to `primary_type`
- whether map parameters still must be JSON-encoded for the current Privy SDK
- whether the SDK still returns signatures in a format fully compatible with `EIP712Signature.fromHex(...)`

### D. Revalidate Reown typed-data and transaction transport behavior
Affected file:
- `lib/services/reown_service.dart`

Review focus:
- whether `eth_signTypedData_v4` still accepts the raw map shape as passed today
- whether `eth_sendTransaction` still accepts the app-built request without additional normalization
- whether chain switching assumptions still match current SDK behavior

### E. Review transaction request augmentation
Affected file:
- `lib/protocol/attestation_service.dart`

Review focus:
- app-added `chainId` field in the wallet request
- optional `sponsor` flag
- whether these fields are harmless extras or required wallet-specific behavior

### F. Review custom onchain polling / parsing
Affected file:
- `lib/protocol/attestation_service.dart`

Review focus:
- UID extraction from receipt logs
- schema record parsing from raw ABI return data
- timestamp existence checks through raw `eth_call`

Reason for review:
- this code is app-specific and more exposed to assumptions than the library-backed signing path

---

## Likely Compliant / Low Concern Areas

### `lib/protocol/external_wallet_signer.dart`
The adapter follows the upstream `Signer` pattern directly and has very little policy of its own.

### `lib/providers/app_wallet_provider.dart`
The provider correctly treats signer construction as an application concern rather than a library concern.

### `lib/providers/schema_provider.dart`
The provider uses `SchemaDefinition` and `SchemaUID.compute(...)` the way the latest library guidance describes.

### `lib/widgets/chain_selector.dart`
The use of `ChainConfig.supportedChainIds` and `ChainConfig.forChainId(...)` matches current upstream guidance.

### `lib/protocol/attestation_service.dart` architecture
The overall architecture is sound even where individual details need review:
- `Signer` drives offchain work
- static builders drive wallet onchain work
- app code owns wallet transport concerns

---

## Prioritized Edit Queue

1. **Fix `bytes[]` parsing in dynamic schema screens**
   - `lib/screens/sign_screen.dart`
   - `lib/screens/onchain_attest_screen.dart`

2. **Centralize and harden attestation JSON import/export**
   - `lib/widgets/attestation_result_card.dart`
   - `lib/screens/verify_screen.dart`
   - likely a new shared utility under `lib/utils/`

3. **Revalidate wallet transport details for Privy and Reown**
   - `lib/protocol/privy_signer.dart`
   - `lib/services/reown_service.dart`
   - `lib/providers/app_wallet_provider.dart`

4. **Review and simplify brittle onchain parsing where possible**
   - `lib/protocol/attestation_service.dart`

---

## Suggested Implementation Notes

### For `bytes[]` UI parsing
Preferred input convention:
- comma-separated `0x`-prefixed hex strings

Example:
- `0x1234,0xabcd,0xdeadbeef`

Minimum implementation expectations:
- trim whitespace
- reject odd-length hex
- reject non-hex characters
- convert each item into `Uint8List`
- keep `string[]` behavior unchanged

### For attestation JSON handling
Minimum implementation expectations:
- one shared encoder / decoder used by both export and verify paths
- support the exact app-exported format first
- treat compatibility with external or historic formats as a separate, explicit decision

### For wallet integrations
Minimum implementation expectations:
- test Privy and Reown against current upstream typed-data expectations using a real signing path
- verify that wallet signing still returns signatures accepted by `EIP712Signature.fromHex(...)`
- verify onchain requests work for attestation, registration, and timestamping

---

## Success Criteria For Follow-up Code Changes
The audit is only complete when later implementation work can satisfy all of the following:
- `flutter analyze` passes cleanly
- targeted tests cover sign, verify, and onchain flows
- app-exported attestation JSON can be re-imported and verified reliably
- dynamic `bytes[]` schema fields sign and encode correctly
- manual smoke tests succeed for both Privy-backed and Reown-backed wallet flows

## Notes
This document should be treated as the authoritative migration checklist for updating the app against the latest `location_protocol` upstream `main` guidance.
