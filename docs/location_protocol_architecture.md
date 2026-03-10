# Location Protocol Architecture & Implementation

This document provides a conceptual overview of the Location Protocol and details the specific assumptions and implementation details within this Flutter Signature Service application.

## Overview

At its core, the [Location Protocol](https://spec.decentralizedgeo.org/introduction/overview/) is a signature service designed to guarantee the integrity and authorship of location records.

The primary goal of this application is to implement the capabilities of creating location attestations as defined by the [Astral SDK](https://github.com/DecentralizedGeo/astral-sdk). It achieves this by using the [Ethereum Attestation Service (EAS)](https://docs.attest.org/docs/purpose/attestation-ecosystem) and its [EAS SDK TypeScript Library](https://github.com/ethereum-attestation-service/eas-sdk) as the reference implementation.

## Architecture and Signing Process

The following sequence diagram illustrates the flow of creating an offchain location attestation within this application:

```mermaid
sequenceDiagram
    participant User
    participant App as Flutter App
    participant Builder as AttestationBuilder
    participant Encoder as AbiEncoder
    participant Signer as EIP712Signer
    participant EAS as EAS Format (Offchain)

    User->>App: Submits Lat, Lng, & Memo
    App->>Builder: Create UnsignedLocationAttestation
    Builder-->>App: Returns Unsigned Attestation Object

    App->>Signer: signLocationAttestation(Unsigned, PrivateKey)
    
    Signer->>Encoder: Encode data parameters
    Note right of Encoder: Encodes (srs, locationType, location, etc.) into ABI bytes
    Encoder-->>Signer: Returns encoded data hex

    Signer->>Signer: Construct EIP-712 Domain Separator & Types
    Signer->>Signer: Hash message & sign with PrivateKey
    Note User: Private Key is loaded from secure local storage

    Signer-->>App: Returns OffchainLocationAttestation (v,r,s signatures)

    App->>EAS: Format to EasOffchainJson
    EAS-->>App: JSON String ready for verification or sharing
    App-->>User: Displays Signed Attestation result
```

## Implementation Assumptions

During the development of this signature service, several specific technical assumptions were made to streamline the signing functionality:

### 1. Offchain Focus
The application is entirely focused on generating **Offchain Attestations** using EIP-712 typed data signing. It omits the complexities of on-chain transactions, gas management, or broadcasting smart contract calls, keeping the scope strictly to data integrity through cryptographic signatures.

### 2. Hardcoded EAS Environment (Sepolia)
For the purpose of this implementation, the target environment is hardcoded to the **Sepolia Testnet**.
- **EAS Verifying Contract:** `0xC2679bEA14028036CB4122E1A16c96bA6dC79E89`
- **Chain ID:** `11155111`
- **Schema UID:** `0x19943bf08b1a8f6d6edadd49ad91fdcd9720dcbee628cfd600115e5c7096d24a` (This specific schema defines the structure for the Location Protocol fields).

### 3. Default Attestation Fields
When constructing the attestation payload, default values are applied where specific overrides are not provided by the user interface:
- **`revocable`**: Set to `true` by default.
- **`expirationTime`**: Set to `0` (indicating no expiration).
- **`refUID`**: Hardcoded to `0x0000000000000000000000000000000000000000000000000000000000000000` (zero bytes), since these attestations currently stand alone and do not reference previous records.
- **`recipient`**: Hardcoded to the zero address (`0x0000...`) if none is provided.

### 4. Key Management & Signer Role
The application assumes that the user will generate or import a raw Ethereum private key into the local secure storage. This key acts as the designated signer for all location attestations created within the app. No external wallet connections (like WalletConnect or MetaMask) are currently integrated; signing is performed entirely in memory using the Dart `web3dart` package.
