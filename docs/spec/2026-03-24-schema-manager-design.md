# Design Spec: Schema Manager

## Overview
The Schema Manager feature allows users to query, modify, and register Location Protocol schemas directly within the app. It replaces the existing static "Register Schema" screen with a dynamic interface that supports custom field management and EAS Scan integration.

## User Requirements
- Query schemas registered by the currently connected wallet from EAS Scan.
- Display schema fields in a table.
- Add or remove user fields (LP base fields stay hidden but are included in the UID).
- Compute and display the Schema UID in real-time.
- Register the active schema on-chain.
- Support schema design/selection even with an imported private key (offchain mode).
- Persist the active schema across app restarts.

## Architecture

### 1. State Management (`SchemaProvider`)
We will introduce a `SchemaProvider` (using the `provider` package) to serve as the global source of truth for the "Active Schema".

```dart
class SchemaProvider extends ChangeNotifier {
  SchemaDefinition _definition;
  String _activeSchemaUID;
  
  // Getters
  SchemaDefinition get definition => _definition;
  String get schemaUID => _activeSchemaUID;
  
  // Actions
  void addField(SchemaField field);
  void removeField(String name);
  void setSchema(SchemaDefinition newDef);
  void resetToDefault();
}
```

### 2. GraphQL Integration
The `AttestationService` will be extended to support querying schemas.

**Endpoint Discovery**:
- Use `NetworkLinks` to get the base domain. I'll add a helper `getEasScanDomain(chainId)` if it doesn't exist.
- The GraphQL endpoint is `${domain}/graphql`.

**GraphQL Query**:
```graphql
query Schemas($where: SchemaWhereInput) {
  schemas(where: $where, orderBy: [{index: desc}]) {
    id
    schema
    creator
    index
  }
}
```
`$where` will filter for `creator: { equals: userAddress }`.

### 3. UI: Schema Manager Screen
A new standalone screen (`SchemaManagerScreen`) will implement the UI:
- **Registered Schema Dropdown**: Fetched from EAS Scan.
- **Active Schema Info**: Displays UID and copy button.
- **Fields Table**: 
  - Lists **user fields** with "Remove" buttons.
  - **LP Base Fields** (`lp_version`, `srs`, `location_type`, `location`) are hidden but automatically included by the library.
  - **Add Field Row**: 
    - Inputs for name and type.
    - Supported types: `uint256`, `string`, `address`, `bool`, `bytes`, `bytes32`, `string[]`, `bytes[]`.
- **Action Buttons**: 
  - "Reset to Default": Reverts to original 6 fields.
  - "Register Schema Onchain": 
    - Replaces the old `RegisterSchemaScreen`.
    - Dynamic state: "Register" vs "Already Registered".
    - "View on EAS Scan" link when registered.

### 4. Integration Updates
- **`main.dart`**: Initialize `SchemaProvider` and provide it to the widget tree.
- **`AttestationService`**: Refactor to accept `SchemaDefinition` from the provider instead of hardcoded `AppSchema.definition`.
- **Dynamic Field Rendering**: 
  - `OnchainAttestScreen` and `SignScreen` (Offchain) will be updated to dynamically render input fields based on the `SchemaProvider.definition`.
  - Instead of hardcoded `TextFormField`s, they will iterate through the list of `SchemaField`s and generate the appropriate input widget (e.g., `TextFormField` for strings, number input for `uint256`, etc.).
  - The submission logic will dynamically build the `userData` map from these inputs.
- **`HomeScreen`**: Update navigation to point to the new Schema Manager.
- **`RegisterSchemaScreen`**: This file will be replaced/deleted as its logic moves to the Schema Manager.

## Persistence
The `SchemaProvider` will use `SharedPreferences` to store the JSON representation of the active `SchemaDefinition`. On app load, it will attempt to restore this definition, falling back to the default LP definition if none exists.

## Future Considerations
- Supporting more complex EAS types (currently focusing on basic strings, uints, etc.).
- Validating field names for uniqueness and EAS compatibility.
