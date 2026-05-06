# Library Feature: Abstract Signer Interface

## Overview
De-couple the `location_protocol` library from raw private keys by introducing an abstract `Signer` interface. This is essential for supporting external wallets (Privy, WalletConnect, MetaMask) without compromising the library's protocol internals.

## Requirements
- **FR-1**: Define an abstract `Signer` class with `address`, `signDigest(Uint8List)`, and `signTypedData(Map<String, dynamic>)`.
- **FR-2**: Implement `LocalKeySigner` as the default implementation for raw private keys (backward compatibility).
- **FR-3**: Refactor `OffchainSigner` primary constructor to accept `Signer signer` instead of `privateKeyHex`.
- **FR-4**: Provide `OffchainSigner.fromPrivateKey()` as a convenience factory.
- **FR-5**: Ensure zero Flutter dependencies (Pure Dart).

## Acceptance Criteria
- [ ] `Signer` and `LocalKeySigner` implemented in `lib/src/eas/`.
- [ ] `OffchainSigner` correctly delegates signing to the provided `Signer`.
- [ ] Existing tests for `privateKeyHex` continue to pass via the factory.
- [ ] Parity verified: signing with `LocalKeySigner` matches previous implementation exactly.

## Technical Context
Full specification available in `docs/spec/plans/prd-signer-interface.md`.
