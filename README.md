# Location Protocol Signature Service

Location Protocol Signature Service demo app — implements EIP-712 signing of location attestations using the Ethereum Attestation Service (EAS) schema.

## Documentation

For a detailed overview of the protocol architecture implementation in flutter, signing process, and our implementation assumptions, see the [Location Protocol Architecture](docs/location_protocol_architecture.md).

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