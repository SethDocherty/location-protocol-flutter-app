# Feature: Abstract Signer Interface & Wallet Connector

## Description
Redesign the library's signer layer to use an abstract `Signer` interface, decoupling it from raw private keys.

This allows the library to work seamlessly with many wallet providers (Privy, WalletConnect, MetaMask, etc.) while the library continues to own all protocol-specific EIP-712 internals.

## User Stories
- **US-001**: As a developer, I want to plug in a Privy wallet's signing capability without rewriting the library's signing logic.
- **US-002**: As a developer, I want my app to work with both local keys and external wallets using the same interface.

## Acceptance Criteria
- [ ] Abstract `Signer` class defined with `address`, `signDigest()`, and `signTypedData()`.
- [ ] `LocalKeySigner` implementation for backward compatibility.
- [ ] `OffchainSigner` refactored to accept a `Signer` object.
- [ ] Parity tests ensuring `LocalKeySigner` produces the same output as the previous `privateKeyHex` path.

## Technical Details
- **Location**: `lib/src/eas/signer.dart` and `lib/src/eas/local_key_signer.dart`.
- **Implementation**: Based on `prd-signer-interface.md` specifications.
