# Feature: Delegated Attestations

## Description
Implement the EAS delegated signing pattern, allowing users to sign an attestation request that a separate "Relayer" or "Payer" submits on-chain.

This enables account abstraction-like "gasless" experiences where the application covers the transaction costs for its users while maintaining cryptographic proof from the user's private key.

## User Stories
- **US-001**: As a user with no ETH, I want to sign a location record and have the application publish it to the blockchain for me.
- **US-002**: As a developer, I want to provide a seamless onboarding experience by paying the gas for the user's first few attestations.

## Acceptance Criteria
- [ ] Support for creating `DelegatedProxy` signatures for attestation.
- [ ] `DelegatedSigner` class added to handle the specific EIP-712 typing for delegated requests.
- [ ] `EASClient` updated to accept a delegated signature for on-chain submission.
- [ ] Unit tests covering the end-to-end "Sign -> Relate -> Attest" flow.

## Technical Details
- **Location**: `lib/src/eas/delegated_signer.dart`.
- **Note**: This follows the EAS on-chain delegated attestation specification.
