# Feature: Flexible Payload Signing (Dynamic User Data)

## Description
Refactor `AttestationService` and `OffchainSigner` to support arbitrary user data based on dynamic `SchemaDefinition`s.

Currently, the library's high-level signing methods often assume a fixed schema or a limited set of user fields (like 'memo'). This enhancement enables developers to pass a `Map<String, dynamic>` of user data that precisely matches their custom `SchemaDefinition`.

## User Stories
- **US-001**: As a developer with a complex schema (e.g., event logs + images + metadata), I want to sign an offchain attestation by passing all my field values in a single map.
- **US-002**: As a developer, I want to build onchain transaction payloads for external wallets that include my dynamic user data correctly encoded.

## Acceptance Criteria
- [ ] `signOffchainWithData()` added to `AttestationService`.
- [ ] `buildAttestCallDataWithUserData()` added to `AttestationService`.
- [ ] Both methods accept `SchemaDefinition schema` and `Map<String, dynamic> userData`.
- [ ] Maintains backward compatibility with existing fixed-field methods.
- [ ] Throws clear errors if `userData` keys do not match the `SchemaDefinition`.

## Technical Details
- **Location**: `lib/src/protocol/attestation_service.dart`.
- **Internal**: Delegates to `AbiEncoder` for encoding the map into the final EAS byte array.
