# Library Feature: RPC Polling & UID Recovery

## Overview
Implement a robust mechanism to monitor on-chain transaction hashes and recover the resulting Attestation UID from the `AttestationCreated` event logs.

## Requirements
- **FR-1**: Add `waitForAttestation(String txHash)` to `EASClient`.
- **FR-2**: Implement recursive polling with a configurable timeout and interval.
- **FR-3**: Correctly parse the ABI-encoded `AttestationCreated` log to retrieve the 32-byte UID.

## Acceptance Criteria
- [ ] UID successfully recovered from mined transactions in integration tests.
- [ ] Throws `TimeoutException` if the transaction is not mined within the specified window.
- [ ] Throws `Exception` if the transaction reverts.
- [ ] Unit tests with mocked RPC receipts.

## Technical Context
Allows developers to seamlessly transition from transaction submission to using the new UID without writing custom event-listening logic.
