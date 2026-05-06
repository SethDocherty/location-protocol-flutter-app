# Feature: Advanced Location Validators

## Description
Expand the library's built-in location validators to include modern and domain-specific indexing systems beyond the initial 9 canonical types.

Specifically, this adds support for `S2 Cells`, `Plus Codes` (Open Location Codes), and `MGRS` (Military Grid Reference System).

## User Stories
- **US-001**: As a developer, I want to use S2 cell IDs for efficient spatial indexing and proximity searching while keeping the record LP-compliant.
- **US-002**: As a developer, I want to use Plus Codes as a user-friendly way to represent locations without long coordinate strings.

## Acceptance Criteria
- [ ] `S2Validator`, `PlusCodeValidator`, and `MgrsValidator` implemented.
- [ ] Added to the default `LocationValidator.registry`.
- [ ] Comprehensive validation logic for each type (e.g., checking S2 level constraints).
- [ ] Unit tests with valid and invalid inputs for each new type.

## Technical Details
- **Location**: `lib/src/location/validators/`.
- **Dependency**: May require lightweight Dart ports of S2/PlusCode logic if external dependencies are to be avoided (Pure Dart constraint).
