# Library Feature: Advanced Location Validators (S2, Plus Codes)

## Overview
Expand the `location_protocol` validator set to include industry-standard spatial indexing systems. These must be implemented as Pure Dart logic to maintain the library's cross-platform (No Flutter) requirement.

## Requirements
- **FR-1**: Implement `S2` cell ID validator (supporting levels 0-30).
- **FR-2**: Implement `PlusCode` (Open Location Code) validator.
- **FR-3**: Implement `MGRS` (Military Grid Reference System) validator for rugged/grid-based use cases.

## Acceptance Criteria
- [ ] All new validators added to the global `LocationValidator` registry.
- [ ] 100% test coverage for valid/invalid string formats for each type.
- [ ] Zero external dependencies (Pure Dart ports).

## Technical Context
Broadens the library's utility across different geospatial domains (index-first systems, military/emergency, user-friendly codes).
