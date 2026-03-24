# Offchain Operations Redesign Spec

## Goal
Redesign the user interface to merge the separated Wallet connection and specific Offchain/Onchain Signing actions. The application will track the "currently connected" wallet across three distinct connection methods (Embedded Privy Wallet, External Reown Wallet, and Temporary Imported Private Key) under a single unified state interface. 

## Architecture & Components

### 1. Unified `AppWalletProvider` 
Acts as the single source of truth for the application's wallet connection context.
- **State Tracking:**
  - `isConnected` (boolean)
  - `walletAddress` (string)
  - `connectionType` (Enum: `privy`, `external`, `privateKey`, `none`)
- **Capabilities:**
  - `Future<String?> sendTransaction(Map<String, dynamic> txRequest)`: Abstracts the underlying RPC call (Privy's `provider.request` vs Reown's `appKitModal.request`) so the UI can send transactions without knowing the wallet type.
  - `bool get canSendTransactions`: Returns true if the connected wallet supports executing onchain transactions (Privy and Reown will return true, Private Keys will return false).
- **Chain ID Handling (App Dictates Chain):**
  - The App's Settings (`SettingsService.selectedChainId`) dictates the target network.
  - `AppWalletProvider` listens to the wallet's active chain. When calling `getSigner()` for an embedded or external wallet, if the wallet's active network does not match the app settings, it will attempt to request a network switch (e.g. `wallet_switchEthereumChain`). If the user declines or it fails, the signer will throw/warn, preventing signatures on mismatched chains.

### 2. Login Modal (`login_modal.dart`)
- Add an "Import Private Key" option to the unified list alongside SMS/Email/Google/Connect Wallet.
- Tapping it opens the `_PrivateKeyImportSheet()`.
- The imported key is stored purely **in-memory** within the `AppWalletProvider`, preventing permanent disk storage.

### 3. Home Screen Redesign (`home_screen.dart`)
- **Unauthenticated State:** 
  - Removes all disparate "Sign..." buttons.
  - Displays a single "Login with Privy" button which triggers the master login modal offering all 3 methods.
- **Authenticated State:** 
  - Displays the `_WalletCard` showing the active wallet address and its `connectionType`.
  - Merges previous buttons strictly into a single **"Sign Offchain Attestation"** button that relies entirely on `authProvider.getSigner()`.
  - The Onchain operation buttons (Attest, Register, Timestamp) drop their hardcoded dependency on Privy's `EmbeddedEthereumWallet`. They will instead call `authProvider.sendTransaction(txRequest)`, allowing both External and Embedded wallets to execute onchain operations natively.

### 4. Settings Screen Cleanup
- Removes the "Add Private Key" input field from `SettingsScreen` and `SettingsService` completely. Private key testing is now treated as a dynamic login session.

## Additional Considerations & Limitations
1. **Ephemeral Private Keys:** Because we are removing the persistent "Add Private Key" setting to improve security, users utilizing Private Keys for testing will need to re-import their hex key each time the app is fully restarted.
2. **Abstracting Transactions:** Currently, the UI screens (`OnchainAttestScreen`, etc.) hardcode Privy's `EmbeddedEthereumWallet` payload execution. By moving the `eth_sendTransaction` invocation into `AppWalletProvider`, we instantly unlock full Onchain capabilities for External Wallets through Reown while keeping the UI agnostic to the wallet type.
