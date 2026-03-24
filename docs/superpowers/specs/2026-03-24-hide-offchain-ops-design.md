# Design Spec: Hide Offchain Operations Based on Wallet Connection

Date: 2026-03-24
Status: Approved

## Overview
This spec outlines the changes required to hide the "Offchain Operations" section in the application's home screen when a wallet is not connected. This includes hiding both the "Sign Offchain Attestation" and "Verify Attestation" actions.

## Requirements
- The "Offchain Operations" section header and its associated buttons MUST be hidden if no wallet is connected.
- The UI should reactively update when the connection state changes.

## Proposed Changes

### HomeScreen (`lib/screens/home_screen.dart`)
- Update the `build` method to wrap the "Offchain Operations" section in a conditional check based on `walletProvider.isConnected`.

```dart
// Updated code snippet
if (walletProvider.isConnected) ...[
  _SectionHeader('Offchain Operations'),
  _buildSignOffchainButton(context, walletProvider),
  const SizedBox(height: 8),
  _buildVerifyButton(context),
  const SizedBox(height: 24),
],
```

## Testing Strategy
- Manual verification:
  1. Open the app without connecting a wallet. Verify the "Offchain Operations" section is NOT visible.
  2. Connect a wallet (Privy, External, or Private Key). Verify the section becomes visible.
  3. Disconnect/Logout. Verify the section is hidden again.
