# Wallet Infrastructure Packages for Location Protocol PRD

## Summary

Build two standalone Flutter packages, Privy and Reown, plus a small shared wallet core, so app developers can add wallet infrastructure to their Flutter apps and use `location_protocol` for offchain and onchain attestations.

The packages must make it easy to:

- authenticate or connect a wallet
- produce a `location_protocol` `Signer`
- submit onchain transactions for attestations, schema registration, and timestamping
- surface transaction results without coupling protocol logic to UI

## Problem Statement

The current Flutter app demonstrates two wallet paths:

- Privy for embedded wallet authentication and signing
- Reown for external wallet connection and transport

Those paths work, but they are app-shaped rather than reusable. The current code mixes:

- auth/session lifecycle
- wallet signing
- transaction submission
- app UI and composition
- attestation orchestration

That makes it hard for other Flutter apps to adopt the same architecture without copying app-specific code.

## Goals

- Provide drop-in Flutter packages for Privy and Reown.
- Keep `location_protocol` as the protocol engine for payloads, typed-data signing, calldata generation, and attestation verification.
- Expose a small shared wallet core with SDK-neutral interfaces.
- Support both offchain and onchain attestations.
- Keep Privy and Reown implementations isolated from each other.
- Make transaction result handling transport-neutral and UI-agnostic.

## Non-Goals

- Rewriting `location_protocol`.
- Building a universal wallet SDK abstraction that hides all SDK differences.
- Moving app-specific attestation screens into the packages.
- Adding support for wallet SDKs other than Privy and Reown in the first release.
- Creating a blockchain explorer UI layer inside the shared wallet core.
- Providing Riverpod or BLoC adapter layers in the initial release — host apps on those systems use the pure Dart core directly.
- Supporting a local private key signer path — this is a dev/test convenience that stays in the host app and is not part of any wallet package.

## Target Users

### Primary

Flutter developers building apps that need:

- wallet sign-in or wallet connection
- offchain location attestations
- onchain attestations or timestamping
- a reusable wallet integration layer

### Secondary

Developers extending the Location Protocol ecosystem who want:

- a clear wallet abstraction boundary
- a reference implementation for signing and transaction submission

## Product Principles

- `location_protocol` owns protocol behavior.
- Wallet packages own wallet lifecycle and transport.
- Shared abstractions should be small and explicit.
- Privy and Reown should remain implementation-specific where their SDKs differ.
- UI should sit above the reusable packages.
- Each package separates pure Dart wallet logic from Flutter-specific glue; the pure Dart core has no Flutter dependency.

## Proposed Package Structure

Each package is structured using the **package-owned abstractions + thin Flutter glue** pattern. Wallet logic lives in a pure Dart core layer; Flutter-specific concerns (widget tree attachment, modal presentation, state notifiers) live in a thin glue layer on top. This keeps the wallet logic testable without Flutter and avoids forcing a state management choice on host apps.

```
packages/
  wallet_core/        ← pure Dart, no flutter SDK dependency
  privy_wallet/       ← depends on wallet_core, implements its abstract classes
  reown_wallet/       ← depends on wallet_core, implements its abstract classes
```

### Implementation hierarchy

`wallet_core` defines abstract classes. `privy_wallet` and `reown_wallet` each provide concrete implementations of those classes using their respective SDKs. This is the relationship that makes the packages interchangeable from a host app's perspective — a host app can hold a `WalletSigner` reference from `wallet_core` without coupling to either SDK package directly.

| `wallet_core` abstract | `privy_wallet` implementation | `reown_wallet` implementation |
|---|---|---|
| `WalletConnector` | `PrivyWalletConnector` | `ReownWalletConnector` |
| `WalletSigner` | `PrivySigner` | `ReownSigner` |
| `TransactionSender` | `PrivyTransactionSender` | `ReownTransactionSender` |
| `WalletIdentity` | `PrivyWalletIdentity` | `ReownWalletIdentity` |

Neither SDK package defines its own abstractions for these concerns. The `wallet_core` contracts are the only interface boundary; SDK-specific types are implementation details hidden behind them.

### Shared core package (`wallet_core`)

Pure Dart. No `flutter` SDK dependency. Owns SDK-neutral wallet contracts:

- wallet identity
- connection state
- wallet connector interface (including `setChain(String chainId)` for session-level chain selection)
- wallet signer bridge (maps to `location_protocol` `Signer`)
- transaction sender interface
- `TransactionResult` model (broadcast-only: tx hash, chain ID, nonce, gas limit — no block number, gas used, or status)
- `WalletException` hierarchy for typed error handling
- composed adapter interface

The pure Dart core exposes state changes via `Stream<WalletState>`. The Flutter glue layer in each SDK package subscribes to this stream and calls `notifyListeners()` on its `ChangeNotifier` wrapper. This keeps the pure Dart core testable without a Flutter test runner.

`WalletState` is a sealed class with typed variants:

```
WalletState (sealed)
  ├── WalletDisconnected
  ├── WalletConnecting
  ├── WalletConnected(WalletIdentity identity)   ← carries address and SDK-neutral identity fields
  └── WalletAuthenticating                       ← intermediate state during OTP, OAuth, or pairing flows
```

`WalletIdentity` carries `address` and any other SDK-neutral fields. SDK-specific types (`PrivyUser`, `EmbeddedEthereumWallet`, Reown session objects) are implementation details hidden behind the concrete implementations and never appear on `WalletState`.

### Privy package (`privy_wallet`)

Depends on `wallet_core`. The pure Dart core implements `WalletConnector`, `WalletSigner` (`PrivySigner`), `TransactionSender`, and `WalletIdentity` from `wallet_core` using the `privy_flutter` SDK.

**Pure Dart core** owns:

- Privy auth/session lifecycle
- embedded wallet signer (`PrivySigner implements WalletSigner`, backed by `EthereumRpcCaller`)
- transaction submission through Privy (`PrivyTransactionSender implements TransactionSender`)

**Flutter glue layer** owns:

- `PrivyWallet.init(appId, navigatorKey)` — one-time startup wiring
- Login modal exported as a composable widget (not presented imperatively by the package)
- `PrivyWalletNotifier extends ChangeNotifier` wrapping the pure Dart core for host apps using `provider`

### Reown package (`reown_wallet`)

Depends on `wallet_core`. The pure Dart core implements `WalletConnector`, `WalletSigner` (`ReownSigner`), `TransactionSender`, and `WalletIdentity` from `wallet_core` using the `reown_appkit` SDK.

**Pure Dart core** owns:

- Reown session lifecycle
- wallet connect transport
- CAIP-2 chain routing and chain switching
- typed-data signing (`ReownSigner implements WalletSigner`)
- transaction submission through Reown (`ReownTransactionSender implements TransactionSender`)

**Flutter glue layer** owns:

- `ReownWallet.init(projectId, navigatorKey)` — modal attachment wiring via injected `GlobalKey<NavigatorState>`
- `ReownWalletNotifier extends ChangeNotifier` wrapping the pure Dart core for host apps using `provider`

### `BuildContext` and modal presentation

Both Privy and Reown require UI attachment to present modals (login modal for Privy, wallet connect modal for Reown). Both packages solve this the same way: they accept a `GlobalKey<NavigatorState>` at init time, eliminating `BuildContext` from all public wallet API call sites. The host app provides the key once at startup — the same key passed to `MaterialApp`. No `BuildContext` is required after init.

```dart
// Host app startup — same navigatorKey passed to MaterialApp
await PrivyWallet.init(appId: '...', navigatorKey: navigatorKey);
await ReownWallet.init(projectId: '...', navigatorKey: navigatorKey);

// Anywhere in the app — no BuildContext required
final signer = privyWallet.getSigner();
```

Login and connect widgets that the host app drives (e.g., placing a login button) are exported as composable widgets. The package presents modals imperatively via `navigatorKey` only when the SDK requires it (e.g., the WalletConnect pairing flow).

For the Privy login modal specifically, the package exports both the sheet content widget and a `showPrivyLoginModal(context)` helper function. The helper returns `Future<PrivyUser?>` — `null` means the user dismissed the modal without authenticating. On successful authentication, the `PrivyWalletNotifier` also fires `notifyListeners()` independently via the `Stream<WalletState>` subscription, so widgets listening through `provider` update without needing to await the `Future`.

## Core User Stories

### Offchain attestation

- As a developer, I can connect a wallet and obtain a `Signer` compatible with `location_protocol`.
- As a developer, I can sign an offchain location attestation with Privy.
- As a developer, I can sign an offchain location attestation with Reown-connected external wallets.

### Onchain attestation

- As a developer, I can build EAS calldata through `location_protocol`.
- As a developer, I can submit that calldata through either Privy or Reown.
- As a developer, I can receive a transaction hash and related metadata after submission.

### Wallet lifecycle

- As a developer, I can detect whether a wallet is connected.
- As a developer, I can disconnect or reset wallet state.
- As a developer, I can switch or align the active chain where the SDK supports it.

## Functional Requirements

### Shared core

- Must define SDK-neutral wallet state and identity.
- Must define an interface that maps cleanly to `location_protocol` `Signer`.
- Must define a transaction sender interface for `eth_sendTransaction`-style requests.
- Must define `setChain(String chainId)` on the connector interface; chain ID is session state set once (e.g., from app settings) and applied to all subsequent signing and transaction calls.
- Must define a typed `WalletException` hierarchy: `WalletNotInitializedException`, `WalletAuthException`, `WalletSigningException`, `WalletTransactionException`, `WalletCancelledException`. SDK-specific exceptions must not escape past the wallet package boundary — each package maps them to the appropriate `WalletException` subclass.
- Must expose `Stream<WalletState>` as the state contract. Flutter glue layers subscribe to this stream; they do not poll or hold duplicate state.
- Must not import Privy or Reown SDKs.
- Must not include application UI.
- Must not declare `flutter` as an SDK dependency — pure Dart only.
- Must expose all interfaces as pure Dart abstract classes.

### Privy package

- Must support Privy auth and embedded wallet access.
- Must expose a wallet signer implementation for `signTypedData`.
- Must support onchain transaction submission.
- Must preserve Privy-specific signing quirks if required by the SDK.
- The pure Dart core layer must not import any Flutter widget library.
- Must accept a `GlobalKey<NavigatorState>` at `init()` time; no `BuildContext` in any public signing or transaction API.
- Must export the login modal sheet content as a composable widget and a `showPrivyLoginModal(context)` helper returning `Future<PrivyUser?>` (null = dismissed). The package does not present the modal imperatively.
- Must export `PrivyWalletNotifier extends ChangeNotifier` as the Flutter glue layer; it subscribes to the pure Dart core's `Stream<WalletState>` and exposes `WalletState state` and `WalletException? error`. Host apps on other state management systems use the pure Dart `Stream<WalletState>` directly.

### Reown package

- Must support wallet connect session lifecycle.
- Must support CAIP-2 chain routing and chain switching.
- Must expose a wallet signer implementation for `signTypedData`.
- Must support onchain transaction submission through the connected wallet.
- The pure Dart core layer must not import any Flutter widget library.
- Must accept a `GlobalKey<NavigatorState>` at `init()` time; no `BuildContext` in any public signing, connection, or transaction API.
- Must export `ReownWalletNotifier extends ChangeNotifier` as the Flutter glue layer; it subscribes to the pure Dart core's `Stream<WalletState>` and exposes `WalletState state` and `WalletException? error`. Host apps on other state management systems use the pure Dart `Stream<WalletState>` directly.

### Transaction results

- `sendTransaction` returns after broadcast, not after on-chain confirmation.
- `TransactionResult` carries fields available at broadcast time: tx hash, chain ID, nonce, and gas limit. It does not include block number, gas used, or on-chain status — those require mining and are the host app's responsibility to fetch if needed.
- Failed transactions (rejection, insufficient gas, revert) throw `WalletTransactionException`. `TransactionResult` only represents a successfully broadcast transaction.
- Must not require protocol parsing inside the wallet packages.
- May carry raw SDK metadata for host-app display.

## Boundaries

### In scope for wallet packages

- connect/disconnect
- wallet identity
- `signTypedData`
- transaction request submission
- chain switching where supported

### In scope for `location_protocol`

- payload construction
- EIP-712 signing semantics
- offchain attestation signing and verification
- calldata generation
- attestation UID and receipt interpretation if protocol-level

### In scope for host app

- screens
- navigation
- formatting transaction results
- explorer links
- app-specific state and composition
- active signer selection when multiple wallet packages are in use (e.g., choosing between a Privy signer and a Reown signer for a given operation)
- local private key signer (dev/test path)

## Success Criteria

The work is successful if:

- a Flutter app can add Privy or Reown as a package dependency
- the app can create a `location_protocol` `Signer` from either package
- offchain attestations work through both wallet paths
- onchain transactions work through both wallet paths
- wallet transport code is reusable in another app without copying the current host app
- the shared core stays independent of both SDKs
- the pure Dart core of each package can be tested without a Flutter test runner
- no `BuildContext` appears in any public signing, connection, or transaction API (widget constructors for exported composable widgets are exempt)

## Risks

- Privy and Reown may look similar at the request level but differ in lifecycle behavior.
- Chain switching may not be equally supported by both SDKs.
- Onchain result handling may tempt protocol/UI coupling if the boundary is not kept strict.
- Over-abstracting the wallet layer could produce a leaky, awkward API.
- The pure Dart / Flutter glue split requires discipline — a single errant `import 'package:flutter/widgets.dart'` in `wallet_core` collapses the separation. This should be enforced by a lint rule or CI import check.
- `location_protocol` is at `0.1.0`; pre-1.0 semver allows breaking changes in minor bumps. All three packages are in a monorepo with path references, so interface changes do not require coordinated pub.dev releases during development. Versioning coordination becomes relevant only when publishing to pub.dev.
- Privy and Reown SDKs may themselves have pre-1.0 or rapidly changing APIs. Minimum acceptable SDK versions should be pinned in each package's `pubspec.yaml` and reviewed before each release.

## Key Decisions

- Use a three-package setup: shared core, Privy, Reown.
- Keep `location_protocol` responsible for protocol logic, not wallet transport.
- Use composition and interfaces, not a large inheritance hierarchy.
- Treat chain switching as capability-based, not mandatory.
- Keep transaction result presentation outside the protocol core.
- Adopt the **package-owned abstractions + thin Flutter glue** pattern: pure Dart core for all wallet logic, thin Flutter layer for `navigatorKey` injection and widget exports. This is the same pattern used by `go_router`, `firebase_auth`, and `supabase_flutter`.
- Both Privy and Reown packages accept a `GlobalKey<NavigatorState>` at `init()`. This is the single point of Flutter-tree attachment; no `BuildContext` appears in any public signing, connection, or transaction API after init. Widget constructors for exported composable widgets are exempt.
- All three packages live in a monorepo with path references. `wallet_core` is not published to pub.dev during development. Publishing is deferred until a second consumer exists and the interfaces have stabilized.
- `location_protocol` is a published pub.dev dependency (`^0.1.0`). The current app's git reference to `main` should be migrated before package work begins. Both `privy_wallet` and `reown_wallet` depend directly on `location_protocol` for the `Signer` interface; `wallet_core` does not import `location_protocol`.
- Chain ID is session state. `setChain(String chainId)` is defined on the connector interface in `wallet_core` and called from the host app's settings save handler. It is not passed per-transaction on the request model.
- The login modal (Privy) is implemented as an exported sheet content widget plus a `showPrivyLoginModal(context)` helper returning `Future<PrivyUser?>`. Null return means dismissed. The notifier fires independently via `Stream<WalletState>`. The package does not present the modal imperatively.
- The pure Dart core exposes state via `Stream<WalletState>`. The `ChangeNotifier` wrappers in each Flutter glue layer subscribe to this stream and call `notifyListeners()`. Each notifier exposes `WalletState state` and `WalletException? error`. Host apps on Riverpod, BLoC, or other state systems consume the `Stream<WalletState>` directly.
- Error handling uses a typed `WalletException` hierarchy defined in `wallet_core`. SDK-specific exceptions do not escape past the package boundary. `WalletNotInitializedException` is thrown for programmer errors (calling methods before `init()`). `WalletCancelledException` is thrown when the user dismisses a modal without completing auth. All other failure modes map to `WalletAuthException`, `WalletSigningException`, or `WalletTransactionException`.
- `TransactionResult` is broadcast-only. It carries tx hash, chain ID, nonce, and gas limit. Block number, gas used, and on-chain status are not included — they require mining and are the host app's responsibility. Failed transactions throw `WalletTransactionException`; they do not produce a `TransactionResult`.
- Transaction result formatting is the host app's responsibility. `TransactionResult` exposes raw fields needed for display but does not format or present them.

## Recommended Next Step

This PRD should be enough to create a separate implementation plan in another agent session. The next plan should break the work into:

0. migrate the host app's `location_protocol` dependency from the git `main` reference to `^0.1.0` on pub.dev
1. shared core package
2. Privy package
3. Reown package
4. host app migration and cleanup
5. tests and verification
