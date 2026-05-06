# Feature: EasScan GraphQL Service

## Description
A new service layer within the `location_protocol` library to facilitate fetching and parsing schemas directly from [EAS Scan](https://easscan.org).

Currently, developers using the library have to write their own GraphQL implementation to discover and resolve schemas registered by users on-chain. This feature will provide a standard, performant, and correctly-typed way to fetch schemas by creator address or specific UID.

## User Stories
- **US-001**: As a developer, I want to query all LP-compliant schemas created by a specific wallet address so that my app can display a list of available schemas to the user.
- **US-002**: As a developer, I want to fetch the ABI field list of a schema by its UID so that my app can dynamically render input fields for it.
- **US-003**: As a developer, I want the library to handle network-specific EAS Scan URLs automatically based on the `ChainId`.

## Acceptance Criteria
- [ ] `EasScanService` class implemented in `lib/src/protocol/`.
- [ ] Support for querying schemas by creator address.
- [ ] Support for fetching a single schema by UID.
- [ ] Automatic support for all 21+ chains already in `ChainConfig`.
- [ ] Handles EIP-55 checksumming for addresses to satisfy EAS Scan API requirements.
- [ ] Includes unit tests with mocked HTTP client responses.

## Technical Details
- **Dependency**: Built on `http`.
- **API**: Returns `List<RegisteredSchema>` or `RegisteredSchema?`.
- **Location**: `lib/src/protocol/eas_scan_service.dart`.
