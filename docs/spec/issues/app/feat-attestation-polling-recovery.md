# Feature: Attestation Polling & Recovery

## Description
Provide a robust utility for monitoring on-chain transaction hashes to recover the resulting Attestation UID.

Currently, when a user submits an on-chain attestation, the app must manually wait for confirmation and parse the transaction logs to find the new UID. This feature encapsulates that logic into a single async method.

## User Stories
- **US-001**: As a developer, I want to submit a transaction and await the final `AttestationUID` so that my app can immediately link to the new record on EAS Scan.
- **US-002**: As a developer, I want to handle transaction failures or timeouts gracefully while polling for an attestation.

## Acceptance Criteria
- [ ] `waitForAttestation(String txHash)` method added to `EASClient`.
- [ ] Automatically polls the RPC until the transaction is mined or a timeout is reached.
- [ ] Correctly decodes the `AttestationCreated` event from the transaction receipts.
- [ ] Returns the 32-byte UID as a 0x-prefixed hex string.
- [ ] Unit tests with mocked RPC responses.

## Technical Details
- **Location**: `lib/src/rpc/eas_client.dart`.
- **Implementation**: Uses `RpcProvider.getReceipt(txHash)` and filters logs for the `AttestationCreated` event signature.
