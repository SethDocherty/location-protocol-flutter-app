# Location Protocol Signature Service

A Flutter application for creating and verifying location attestations using the Ethereum Attestation Service (EAS). Supports onchain and offchain EIP-712 signing via Privy embedded wallets, Reown/WalletConnect (MetaMask, etc.), and imported private keys. Includes schema management with UID generation and onchain registration across 19+ EVM networks.

## Documentation

- **[Location Protocol Architecture](docs/location_protocol_architecture.md)** — Overview of the app's capabilities, signing methods (Privy, Reown, imported keys), provider architecture, schema management, and multi-chain support.

- **[Custom Wallet Signers](docs/custom-wallet-signers.md)** — Deep dive into the design and implementation of `PrivySigner` and `ExternalWalletSigner` classes that bridge Privy and Reown to the `location_protocol` library's `Signer` interface.

- **[Walkthrough](walkthrough.md)** — Module-by-module breakdown of the app structure, key flows for signing and verification, schema management, and test coverage.

## Prerequisites

To build and run this application, you must have Flutter installed on your machine. If you haven't set up Flutter yet, please follow the official installation guide:

- [Install and Setup Flutter](https://docs.flutter.dev/install/custom)

## Getting Started

1. **Clone the repository**:

   ```bash
   git clone https://github.com/SethDocherty/location-protocol-flutter-app.git
   cd location-protocol-flutter-app
   ```

2. **Install dependencies**:

   ```bash
   flutter pub get
   ```

## Running the App

To run the application in development mode:

```bash
flutter run
```

## Testing

To execute the unit and widget tests:

```bash
flutter test
```
