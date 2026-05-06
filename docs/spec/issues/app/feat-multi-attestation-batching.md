# Feature: Multi-Attestation (Batching)

## Description
Enable batching of multiple location attestations into a single on-chain transaction using EAS `multiAttest`.

For applications that need to submit many location records (e.g., a path with many points or a sensor network heartbeats), this feature significantly reduces transaction overhead and gas costs by aggregating them into one call.

## User Stories
- **US-001**: As a developer, I want to submit 10 location records at once to save gas for my users.
- **US-002**: As a developer, I want to mix different schemas in a single multi-attestation call.

## Acceptance Criteria
- [ ] `multiAttest` support added to `EASClient`.
- [ ] New model classes for `MultiAttestationRequest` and `MultiAttestationResult`.
- [ ] `AbiEncoder` updated to handle the complex encoding requirements for EAS multi-attest.
- [ ] Unit tests for multi-attestation with mixed schemas.

## Technical Details
- **Location**: `lib/src/rpc/eas_client.dart` and `lib/src/abi/abi_encoder.dart`.
- **Note**: This requires careful encoding of the `MultiAttestationRequest[]` array for the EAS contract.
