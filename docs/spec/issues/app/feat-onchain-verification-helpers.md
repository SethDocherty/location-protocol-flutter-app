# Feature: Onchain Verification Helpers

## Description
Add helper methods to `AttestationService` to verify the state of a schema on-chain before attempting to use it for an attestation.

The primary use case is checking if a schema UID computed locally (from a `SchemaDefinition`) has already been registered in the `SchemaRegistry` contract. This prevents redundant registration transactions and avoids "Schema not found" errors during on-chain attestations.

## User Stories
- **US-001**: As a developer, I want to check if my schema is registered before prompting the user for a registration transaction.
- **US-002**: As a developer, I want to verify that a schema UID provided by an external source is actually valid on the current network.

## Acceptance Criteria
- [ ] `isSchemaUidRegistered(String uid)` method added to `AttestationService`.
- [ ] Correctly handles 0x-prefixed and non-prefixed UIDs.
- [ ] Integration with `DefaultRpcProvider` to call `getSchema` on the on-chain Registry.
- [ ] Unit tests for both "registered" and "unregistered" scenarios.

## Technical Details
- **Location**: `lib/src/protocol/attestation_service.dart`.
- **Logic**: Calls `SchemaRegistry.getSchema(uid)`. If the returned record contains a non-zero UID matching the request, it's registered.
