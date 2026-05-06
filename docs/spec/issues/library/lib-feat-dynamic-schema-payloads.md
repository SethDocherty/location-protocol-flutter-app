# Library Feature: Dynamic Schema & Payload Support

## Overview
Enhance `AttestationService` to support arbitrary user data payloads based on dynamic `SchemaDefinition` objects. Currently, the service is optimized for fixed schemas.

## Requirements
- **FR-1**: Add `signOffchainWithData()` method that accepts a raw `Map<String, dynamic> userData`.
- **FR-2**: Add `buildAttestCallDataWithUserData()` for on-chain flows.
- **FR-3**: Integrate with `AbiEncoder` to ensure the dynamic map is correctly padded and encoded according to the Provided `SchemaDefinition`.

## Acceptance Criteria
- [ ] New methods added to `AttestationService`.
- [ ] Successfully encodes complex types (e.g., `string[]`, `bytes32`) from dynamic maps.
- [ ] Throws `ArgumentError` if the map keys do not match the `SchemaDefinition` field names.
- [ ] Unit tests using non-standard (user-defined) field combinations.

## Technical Context
Unlocks the "Schema Manager" use case where users define their own fields at runtime.
