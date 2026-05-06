# Feature: Revocation Lifecycle Support

## Description
Add first-class support for revoking attestations, both on-chain (via transaction) and off-chain (where applicable).

Currently, the library focuses heavily on creation and verification. This feature completes the attestation lifecycle by enabling users and apps to invalidate previously created location records.

## User Stories
- **US-001**: As a user, I want to revoke my on-chain location attestation if I no longer wish for it to be active or valid.
- **US-002**: As a developer, I want to programmatically revoke attestations when certain business conditions are met.

## Acceptance Criteria
- [ ] `revoke(String uid)` method added to `EASClient` to build and submit on-chain revocation.
- [ ] Support for offchain revocation patterns (e.g., publishing a "Revoked" attestation that references the original UID).
- [ ] Verification logic updated to check for revocation status if an RPC provider is available.
- [ ] Unit tests for the revocation flow.

## Technical Details
- **Location**: `lib/src/rpc/eas_client.dart`.
- **Note**: Revocation is only possible if the schema was registered as `revocable: true`.
