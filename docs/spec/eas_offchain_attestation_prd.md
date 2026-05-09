# PRD: EAS-Compatible Offchain Attestation Serialization and Verification for Dart/Flutter

## Overview

This document defines the product and engineering requirements for making a Dart package and Flutter app fully compatible with Ethereum Attestation Service (EAS) offchain attestation signing, storage, export, import, and verification flows.[cite:5][cite:21] The target outcome is that offchain attestations created in the Flutter app can be verified both locally and by EAS-compatible tooling using the original EIP-712 typed-data envelope rather than a flattened, app-specific JSON representation.[cite:5][cite:21][cite:23]

## Background

EAS supports attestations as structured claims and distinguishes between onchain and offchain usage patterns.[cite:12][cite:24] For offchain attestations, the signed object is an EIP-712 typed structured data payload, which means verification depends on the exact `domain`, `primaryType`, `types`, and `message` that were originally signed.[cite:5][cite:21][cite:23]

In the current implementation, the app successfully signs a payload and can locally recover a signer address from a flattened attestation object, but the exported JSON does not preserve the full EAS envelope expected by EAS verification flows.[cite:5][cite:21] As a result, an attestation may appear valid inside the app while still failing in EAS verification tools because the original typed-data context cannot be reconstructed from the exported JSON alone.[cite:5][cite:23]

## Problem Statement

The current app exports a flattened JSON object with top-level fields such as `uid`, `schemaUID`, `recipient`, `time`, `data`, `salt`, `version`, `signature`, and `signer`.[cite:21] That format is useful for UI display, but it omits the nested `sig` object used by EAS examples and verification flows, including `sig.domain`, `sig.primaryType`, `sig.types`, `sig.message`, and `sig.signature`.[cite:5][cite:21]

EAS verification requires two things to line up exactly:

- The offchain UID must recompute from the message fields that were signed.[cite:5][cite:9]
- The EIP-712 signature must recover the expected signer from the original typed-data payload, including the original domain separator values.[cite:5][cite:23]

Because the current export format drops the original EIP-712 envelope and renames at least one critical field (`schemaUID` instead of `schema`), the exported attestation cannot be reliably verified by EAS tooling even when the local app can recover the signer address from a custom verification routine.[cite:5][cite:21][cite:23]

## Goal

Implement an EAS-compatible offchain attestation pipeline in the Dart package and Flutter app so that newly created attestations are stored, exported, imported, and verified using the canonical EAS JSON envelope.[cite:5][cite:21] The implementation must preserve the exact typed-data payload used during signing and must verify attestations locally using the same high-level semantics as the EAS SDK: UID validation plus typed-data signature validation.[cite:5][cite:9][cite:23]

## Success Criteria

A release is successful when all of the following are true:

- New offchain attestations are exported in canonical EAS envelope format with top-level `signer` and nested `sig` content.[cite:21]
- Version 2 attestations include `salt` in the signed message and in UID derivation.[cite:9][cite:21]
- The Flutter app can import the canonical JSON, verify it locally, and display whether failure is due to UID mismatch, signature mismatch, unsupported version, or malformed payload.[cite:5]
- Canonical attestations exported by the app verify successfully in EAS-compatible verification tooling for supported networks and contracts.[cite:5][cite:22]

## Non-Goals

This work does not include redesigning onchain attestation flows, changing the underlying business schema for the location protocol payload, or adding generic support for non-EAS typed-data envelopes.[cite:12][cite:24] The focus is compatibility with EAS offchain attestations and the EIP-712 structures EAS relies on for signing and verification.[cite:5][cite:21][cite:23]

## Users and Use Cases

### Primary Users

- Maintainers of the Dart package and Flutter app who need deterministic, portable attestation generation and verification.[cite:21][cite:23]
- Technical users who want to export attestations from the app and verify them with EAS-compatible tools.[cite:5][cite:22]

### Core Use Cases

- Sign an offchain attestation in Flutter and persist the exact EAS-compatible typed-data envelope.[cite:21][cite:23]
- Export the canonical JSON to a file or clipboard for external verification.[cite:21][cite:22]
- Import a canonical attestation JSON into the app and verify it locally.[cite:5]
- Migrate legacy flat attestation objects into canonical EAS format when the original signing domain is known.[cite:21][cite:23]

## Canonical Data Model

The canonical persisted object must match the EAS offchain envelope pattern shown in the docs, with `signer` at the top level and a nested `sig` object containing the typed-data envelope and signature material.[cite:5][cite:21]

```json
{
  "signer": "0x...",
  "sig": {
    "domain": {
      "name": "EAS Attestation",
      "version": "0.26",
      "chainId": 1,
      "verifyingContract": "0x..."
    },
    "primaryType": "Attest",
    "types": {
      "Attest": [
        { "name": "version", "type": "uint16" },
        { "name": "schema", "type": "bytes32" },
        { "name": "recipient", "type": "address" },
        { "name": "time", "type": "uint64" },
        { "name": "expirationTime", "type": "uint64" },
        { "name": "revocable", "type": "bool" },
        { "name": "refUID", "type": "bytes32" },
        { "name": "data", "type": "bytes" },
        { "name": "salt", "type": "bytes32" }
      ]
    },
    "uid": "0x...",
    "message": {
      "version": 2,
      "schema": "0x...",
      "recipient": "0x...",
      "time": 0,
      "expirationTime": 0,
      "revocable": true,
      "refUID": "0x...",
      "data": "0x...",
      "salt": "0x..."
    },
    "signature": {
      "v": 27,
      "r": "0x...",
      "s": "0x..."
    }
  }
}
```

This format must become the system of record for all newly created offchain attestations.[cite:21] Any simplified or flattened representation used in the UI must be derived from this canonical object rather than stored as the authoritative source.[cite:21][cite:23]

## Field Mapping from Legacy Format

The current flat export can be mapped into the canonical EAS shape, but only if the original signing domain is supplied from configuration or saved state because the EIP-712 domain cannot be reconstructed safely from the flattened payload alone.[cite:23] The required mappings are straightforward for most fields, but `schemaUID` must be renamed to `schema`, and all message fields must move under `sig.message`.[cite:21]

| Legacy field | Canonical field | Notes |
|---|---|---|
| `signer` | `signer` | Top-level value preserved.[cite:21] |
| `uid` | `sig.uid` | Must match recomputed offchain UID.[cite:9] |
| `schemaUID` | `sig.message.schema` | Rename required for EAS compatibility.[cite:21] |
| `recipient` | `sig.message.recipient` | Direct move.[cite:21] |
| `time` | `sig.message.time` | Direct move.[cite:21] |
| `expirationTime` | `sig.message.expirationTime` | Direct move.[cite:21] |
| `revocable` | `sig.message.revocable` | Direct move.[cite:21] |
| `refUID` | `sig.message.refUID` | Direct move.[cite:21] |
| `data` | `sig.message.data` | Direct move.[cite:21] |
| `version` | `sig.message.version` | Direct move.[cite:21] |
| `salt` | `sig.message.salt` | Required for version 2 flow.[cite:9][cite:21] |
| `signature.v` | `sig.signature.v` | Direct move.[cite:21] |
| `signature.r` | `sig.signature.r` | Direct move.[cite:21] |
| `signature.s` | `sig.signature.s` | Direct move.[cite:21] |

## Functional Requirements

### 1. Dart Models

The Dart package must define explicit model classes for the canonical envelope and its substructures:[cite:21]

- `EasOffchainAttestation`
- `EasSig`
- `EasDomain`
- `EasTypeField`
- `EasAttestMessage`
- `EasSignature`
- `EasVerificationResult`

Each model must support JSON serialization and deserialization, field-level validation, and stable serialization behavior for downstream signing and verification logic.[cite:23]

### 2. Canonical Signing Flow

The signing pipeline must construct the EIP-712 typed-data object first, then sign that exact object, then persist the exact signed envelope rather than reconstructing it from display-oriented fields after the fact.[cite:23] The signing flow must capture the original EIP-712 domain values including `name`, `version`, `chainId`, and `verifyingContract`, because those values are part of the domain separator and affect the signature digest.[cite:23]

Required signing sequence:

1. Build `domain`.
2. Build `message`.
3. Build `types`.
4. Construct the full typed-data envelope.
5. Sign the typed-data envelope.
6. Compute the offchain UID from the signed message fields.
7. Persist the canonical envelope with `signer`, `sig`, `uid`, and `signature`.[cite:5][cite:9][cite:23]

### 3. Version 2 Support

The required implementation scope is version 2 offchain attestations using `salt` as part of the signed message and UID derivation.[cite:9][cite:21] Optional support for older formats that use `nonce` may be added later, but this PRD treats version 2 as the required compatibility target.[cite:21]

### 4. UID Computation

The package must implement an EAS-compatible UID computation function for version 2 attestations.[cite:9] The function must use the exact message fields and exact field order required by EAS, ABI-encode them with the correct Solidity-compatible types, and compute the final digest with Keccak-256.[cite:9][cite:23]

Required UID inputs:

- `schema`
- `recipient`
- `time`
- `expirationTime`
- `revocable`
- `refUID`
- `data`
- `salt`[cite:9]

The implementation must expose this as a pure reusable function so it can be called during signing, migration validation, unit tests, and local verification.[cite:9]

### 5. Local Verification

The Dart package must expose a local verification routine analogous to EAS SDK offchain verification.[cite:5][cite:9] The routine must:

1. Parse a canonical EAS envelope.
2. Recompute the UID from `sig.message`.
3. Compare the recomputed UID to `sig.uid`.
4. Rebuild the EIP-712 typed-data object from `sig.domain`, `sig.primaryType`, `sig.types`, and `sig.message`.
5. Recover the signer from `sig.signature`.
6. Compare the recovered signer to top-level `signer`.
7. Return a structured result including `isValid`, `uidMatches`, `signatureMatches`, `recoveredAddress`, `claimedSigner`, and `error`.[cite:5][cite:9][cite:23]

### 6. Migration Adapter

A compatibility adapter must be added for converting the current flat JSON shape into the canonical EAS envelope.[cite:21] This adapter must require explicit `domain` input and must refuse conversion when the original signing domain is unavailable, because inferring or substituting domain values would undermine EIP-712 correctness.[cite:23]

### 7. UI Requirements

The Flutter app must continue to show a friendly attestation summary screen, but that summary must be derived from the canonical model rather than being the primary stored representation.[cite:21] The verification screen must accept canonical JSON from text paste or file upload and must display actionable failure states rather than a generic invalid result.[cite:5]

Required verification states:

- Valid
- Invalid JSON shape
- Missing domain
- Unsupported version
- UID mismatch
- Signature mismatch
- Signer recovery failure[cite:5][cite:23]

### 8. Export and Import

The app must support copying canonical JSON to the clipboard, saving canonical JSON to a file, importing canonical JSON from pasted text, and importing canonical JSON from a file.[cite:21][cite:22] The canonical EAS envelope must be the default export format for all new attestations.[cite:21]

## Technical Requirements

### Data Integrity

- Preserve `0x` prefixes on all hex values.[cite:23]
- Normalize addresses consistently for equality checks, while preserving original display values where practical.[cite:23]
- Serialize integer fields as JSON numbers where expected by the typed-data payload.[cite:23]
- Use exact EAS field names, especially `schema` instead of `schemaUID`.[cite:21]

### Determinism

- Do not reorder typed-data fields between signing and verifying.[cite:23]
- Ensure the `types.Attest` list preserves the exact signed order.[cite:23]
- Ensure canonical JSON serialization is stable enough for debugging and fixture comparison, even though JSON object order is not itself the signature primitive.[cite:23]

### Security and Correctness

- Never substitute domain values at verification time.[cite:23]
- Never hash a display-oriented or flattened object when performing EIP-712 verification.[cite:23]
- Treat the canonical signed payload as immutable evidence once signed.[cite:23]
- Reject malformed or partially reconstructed payloads when required inputs are missing.[cite:5][cite:23]

## Proposed API

```dart
class EasOffchainAttestation {
  final String signer;
  final EasSig sig;
}

class EasSig {
  final EasDomain domain;
  final String primaryType;
  final Map<String, List<EasTypeField>> types;
  final String uid;
  final EasAttestMessage message;
  final EasSignature signature;
}

class EasDomain {
  final String name;
  final String version;
  final int chainId;
  final String verifyingContract;
}

class EasTypeField {
  final String name;
  final String type;
}

class EasAttestMessage {
  final int version;
  final String schema;
  final String recipient;
  final int time;
  final int expirationTime;
  final bool revocable;
  final String refUID;
  final String data;
  final String? salt;
  final int? nonce;
}

class EasSignature {
  final int v;
  final String r;
  final String s;
}

class EasVerificationResult {
  final bool isValid;
  final bool uidMatches;
  final bool signatureMatches;
  final String? recoveredAddress;
  final String? claimedSigner;
  final String? error;
}
```

Proposed methods:

```dart
EasOffchainAttestation buildEasEnvelopeFromFlat({
  required Map<String, dynamic> flat,
  required EasDomain domain,
});

String computeOffchainUid({
  required int version,
  required String schema,
  required String recipient,
  required BigInt time,
  required BigInt expirationTime,
  required bool revocable,
  required String refUID,
  required String data,
  String? salt,
});

Future<String> recoverTypedDataSigner(EasSig sig);

Future<EasVerificationResult> verifyOffchainAttestationSignature({
  required String attester,
  required EasOffchainAttestation attestation,
});
```

## User Stories

- As a developer, a canonical offchain attestation format is needed so JSON exported from the app verifies in EAS-compatible tools.[cite:5][cite:22]
- As a Flutter app user, verification feedback is needed that distinguishes UID mismatch from signature mismatch.[cite:5]
- As a maintainer, a migration path is needed from the current flat format to the canonical EAS envelope.[cite:21]
- As an integrator, the original EIP-712 domain and typed-data schema must be preserved so verification remains deterministic across systems.[cite:23]

## Acceptance Criteria

### Signing

- New attestations are stored and exported in canonical EAS envelope format.[cite:21]
- The exported JSON includes all required EAS envelope fields.[cite:5][cite:21]
- For version 2 attestations, `salt` is included in `sig.message` and UID generation.[cite:9][cite:21]

### Verification

- Local verification recomputes and checks the UID before returning success.[cite:9]
- Local verification reconstructs the EIP-712 payload from canonical fields and recovers the signer from the signature.[cite:23]
- Verification output distinguishes malformed payloads, unsupported versions, UID mismatches, and signature mismatches.[cite:5]
- At least one end-to-end fixture exported from the app validates in EAS-compatible verification tooling.[cite:5][cite:22]

### Migration

- Legacy flat JSON can be converted to canonical format when the original domain is explicitly provided.[cite:21][cite:23]
- Migration fails safely when domain information is missing.[cite:23]

### UI

- The app displays canonical attestations in a human-readable way without changing the source-of-truth model.[cite:21]
- Copy/export actions use canonical JSON by default.[cite:21]
- Verify screen accepts canonical JSON via paste and file import.[cite:22]

## Implementation Plan

### Phase 1: Model Layer

- Add canonical data classes.
- Add JSON serializers and parsers.
- Add validation helpers for addresses, hex strings, and required fields.[cite:21][cite:23]

### Phase 2: Signing Pipeline

- Refactor signer flow to build the typed-data envelope first.
- Persist the exact signed envelope.
- Compute and store the offchain UID in canonical form.[cite:9][cite:23]

### Phase 3: Verification Engine

- Implement version 2 UID derivation.
- Implement EIP-712 typed-data signer recovery.
- Add structured verification result output.[cite:5][cite:9][cite:23]

### Phase 4: Migration and UI

- Add flat-to-canonical migration helper.
- Update copy/export flows to output canonical JSON.
- Update verify screen to accept and validate canonical JSON.
- Update signed-result screen to derive display state from canonical data.[cite:21][cite:22]

### Phase 5: Test Coverage

- Add golden JSON tests for canonical output.
- Add serialization round-trip tests.
- Add UID determinism tests.
- Add signature recovery tests with known fixtures.
- Add end-to-end tests covering sign, export, import, local verify, and EAS-tool verification.[cite:5][cite:21][cite:23]

## Test Matrix

### Positive Cases

- Version 2 attestation with valid `salt`, valid domain, correct signature, and matching UID verifies successfully.[cite:9]
- Canonical JSON round-trips through `fromJson` and `toJson` without semantic mutation.[cite:23]
- Exported canonical JSON validates locally and in EAS-compatible verification tooling.[cite:5][cite:22]

### Negative Cases

- Missing `sig.domain` fails with a domain-related error.[cite:5][cite:23]
- `schemaUID` used in place of `schema` fails canonical parsing or typed-data validation.[cite:21]
- Modified `chainId` or `verifyingContract` causes signature mismatch.[cite:23]
- Modified `salt` causes UID mismatch.[cite:9]
- Modified `data` causes UID and signature validation failure.[cite:9][cite:23]
- Reordered `types.Attest` fields cause verification failure when they no longer match the originally signed typed-data schema.[cite:23]

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Reconstructing typed-data after signing instead of persisting it | False negatives in EAS verification | Persist exact typed-data envelope used at signing time.[cite:23] |
| Missing or incorrect domain values | Signature recovery fails | Require original domain values and reject unverifiable payloads.[cite:23] |
| Field renaming drift such as `schemaUID` vs `schema` | Canonical incompatibility | Centralize serializer mappings and validate canonical shape strictly.[cite:21] |
| Wrong field order in `types.Attest` | EIP-712 hash mismatch | Keep a fixed schema constant and test against fixtures.[cite:23] |
| Local app verifies a custom digest instead of EAS digest | Misleading “valid” status | Verify against reconstructed canonical typed-data only.[cite:5][cite:23] |

## Open Questions

- Which Dart or platform crypto library should be the source of truth for EIP-712 hashing and signer recovery?[cite:23]
- Is support for legacy `nonce`-based offchain attestations required in the first release, or should scope remain limited to version 2 with `salt`?[cite:21]
- Which EAS contract addresses and domain versions should be configured by default for the supported deployment targets?[cite:21][cite:22]
- Should migrated flat attestations include metadata indicating they were reconstructed into canonical form after signing?[cite:23]

## Deliverables

- Canonical Dart model layer for EAS offchain attestations.[cite:21]
- Refactored signing pipeline that preserves exact typed-data envelopes.[cite:23]
- Version 2 UID derivation implementation.[cite:9]
- EAS-compatible local verification service with structured diagnostics.[cite:5]
- Flutter UI updates for canonical export, import, and verification.[cite:21][cite:22]
- Migration helper from legacy flat JSON to canonical EAS shape.[cite:21]
- Automated tests and at least one known-good fixture that verifies locally and in EAS-compatible tooling.[cite:5][cite:22]

## Agent Brief

Implement EAS-compatible offchain attestation support in the Dart package and Flutter app by replacing the current flat exported JSON with the canonical EAS envelope, preserving the exact EIP-712 payload used at signing, implementing version 2 UID derivation using `salt`, adding local verification that checks both UID and recovered signer, providing a migration adapter from the old flat format, and updating the Flutter UI so canonical JSON is the default import/export format and generated attestations verify in EAS-compatible tools.[cite:5][cite:21][cite:23]

## References:

- [Verify Offchain Attestation](https://docs.attest.org/docs/developer-tools/verify-attestation)
- [Storing Offchain Attestations](https://docs.attest.org/docs/tutorials/storing-offchain-data)
- [EIP-712](https://eips.ethereum.org/EIPS/eip-712)
- [Core Concepts: Attestations](https://docs.attest.org/docs/core--concepts/attestations)
- [onchain vs offchain](https://docs.attest.org/docs/core--concepts/onchain-vs-offchain)
- [Offchain Attestations](https://docs.attest.org/docs/easscan/offchain)
- [Offchain attestation typescript source code](https://github.com/ethereum-attestation-service/eas-sdk/blob/master/src/offchain/offchain.ts)
