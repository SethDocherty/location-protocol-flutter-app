# Library Feature: Multi-Attestation (ABI Batching)

## Overview
Add specialized ABI encoding support for EAS `multiAttest`. This is a high-impact optimization for gas-conscious location tracking applications.

## Requirements
- **FR-1**: Implement `EASClient.multiAttest()` that accepts an array of `MultiAttestationRequest` objects.
- **FR-2**: Extend `AbiEncoder` to correctly serialize nested arrays of attestations per schema.
- **FR-3**: Ensure the transaction request follows the exact `multiAttest(MultiAttestationRequest[] requests)` signature on the EAS contract.

## Acceptance Criteria
- [ ] Correctly encodes multiple attestations across different schemas in one payload.
- [ ] Parity verified with Ethereum-style hex encoding (keccak256).
- [ ] Unit tests covering edge cases (empty lists, large batches).

## Technical Context
Critical for performance in path-tracking or high-throughput IoT scenarios.
