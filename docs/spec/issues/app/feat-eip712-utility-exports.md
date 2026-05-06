# Feature: EIP-712 Utility Exports

## Description
Expose key internal EIP-712 and UID computation methods as public static utilities.

Currently, much of this logic is encapsulated within `OffchainSigner`. Making it public allows for easier manual integration, inspection, and verification of protocol data outside of the standard high-level flows.

## User Stories
- **US-001**: As a developer building a custom wallet integration, I want to generate the EIP-712 JSON map for an attestation manually to inspect its fields.
- **US-002**: As a developer, I want to compute the deterministic offchain UID of an attestation before it is signed.

## Acceptance Criteria
- [ ] `OffchainSigner.buildOffchainTypedDataJson()` exposed as static public method.
- [ ] `OffchainSigner.computeOffchainUID()` exposed as static public method.
- [ ] Exports structured for easy access via `location_protocol.dart`.
- [ ] Documentation updated to explain the use cases for these utilities.

## Technical Details
- **Location**: `lib/src/eas/offchain_signer.dart`.
- **Note**: This follows requirements FR-6 and FR-7 in the Signer PRD.
