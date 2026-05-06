# Library Feature: EIP-712 & UID Utilities

## Overview
Expose the internal EIP-712 typed data construction and deterministic UID computation as public static utilities. This allows external consumers to inspect, dry-run, or manually sign protocol payloads.

## Requirements
- **FR-1**: Expose `OffchainSigner.buildOffchainTypedDataJson(...)` to return the `Map<String, dynamic>` expected by `eth_signTypedData_v4`.
- **FR-2**: Expose `OffchainSigner.computeOffchainUID(...)` to compute the 32-byte UID without requiring a signature.
- **FR-3**: Ensure all numeric values (chain ID, etc.) are serialized as decimal strings as per EAS spec.

## Acceptance Criteria
- [ ] Public static methods added to `OffchainSigner`.
- [ ] Computed UIDs match UIDs returned by `signOffchainAttestation` for the same inputs.
- [ ] Typed data JSON passes validation against standard EIP-712 parsers.
- [ ] Unit tests for multi-chain UID parity.

## Technical Context
Necessary for advanced integrations where the signing happens outside of the standard library flow (e.g., custom hardware wallet drivers).
