# Gas Sponsorship Integration Design

## Context
The application allows users to create on-chain location attestations using a Privy embedded wallet. These transactions cost gas on the Ethereum network (or L2s like Optimism/Base).
Currently, users with an embedded wallet must fund it with native tokens to pay for gas. Privy provides a Gas Sponsorship feature that uses EIP-7702 paymasters to sponsor transactions, allowing a frictionless user experience.
The goal is to update the app to support this sponsorship.

## Design

### 1. Global Configuration via `.env`
To give the user global control over whether gas sponsorship is enabled (especially given it's currently only used on a specific device/account for testing), we will add a flag to the `.env` file:
```
GAS_SPONSORSHIP=true
```
The `AttestationService` (or its initializing provider) will read this flag via `flutter_dotenv` to determine whether transactions should be sponsored by default. 

### 2. Augment transaction requests with the `sponsor` flag
According to Privy's API reference and integration patterns for `eth_sendTransaction`, gas sponsorship is enabled by passing sponsorship configuration inside or alongside the transaction request sent to the provider.

The Flutter app currently builds on-chain transaction payloads using `TxUtils.buildTxRequest` and sends them directly via the `EmbeddedEthereumWallet`'s JSON-RPC provider method: `wallet.provider.request('eth_sendTransaction', [txRequest])`.

We will modify `AttestationService` to accept a `sponsorGas` boolean initialized from the environment.
Because we don't have explicit documentation on the `privy_flutter` `EthereumRpcRequest` for gas sponsorship, the most standard integration approach based on their API is to extend the `params` array or inject the flag into the transaction.
To support this we will:
1. Allow `AttestationService.buildTxRequest` to accept a `bool? sponsor` parameter that defaults to the class-wide `sponsorGas` flag if absent.
2. If `sponsor` is `true`, we append `sponsor: true` or a `{"action": "sponsor"}` object to the transaction map / params. (Based on common Web3 bundler APIs, the simplest way is appending a top-level `sponsor: true` to the transaction JSON or `[txRequest, {"action": "sponsor"}]`).

**Alternative:** If `privy_flutter`'s `EmbeddedEthereumWallet` exposes a dedicated `sendTransaction` or sponsorship feature in a newer SDK version, we would use that instead. For now, the direct `provider.request('eth_sendTransaction')` is the lowest-common-denominator that gives us control over the payload.

### 3. Verification
Testing this fully requires an actual transaction on a testnet (e.g. Base Sepolia) with a Privy app ID that has Gas Sponsorship configured and enabled for that chain in the Privy Dashboard.
Since we don't have access to the dashboard directly, we relies on unit tests to ensure the payload is built correctly, and the user must manually trigger a transaction to verify the sponsorship goes through.

## Implementation Steps
1. Modify `AttestationService.buildTxRequest` to accept `sponsor` flag.
2. Update the three UI screens to pass the `sponsor` flag (or a modified `txRequest` structure) when calling `eth_sendTransaction`.
3. Ensure existing tests pass and add a new test case for building a sponsored transaction request.
