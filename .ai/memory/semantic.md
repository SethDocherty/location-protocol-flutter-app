# Semantic Memory

- `PrivyAuthProvider` is the app-level auth boundary and exposes `PrivyAuthState` via `InheritedNotifier`.
- `PrivyManager` owns singleton SDK initialization and readiness wait using `getAuthState()` (not deprecated `awaitReady`).
- `AttestationSigner` decouples EIP-712 signing from key material/backend.
- `LocalKeySigner` preserves deterministic local signing for tests and compatibility.
- `PrivyWalletSigner` signs digest via embedded wallet provider RPC and returns `MsgSignature`.
- `EIP712Signer.signLocationAttestationWith(...)` is the async abstraction entrypoint; existing sync method remains intact.
- `AttestationService` acts as the exclusive on/offchain bridge and protocol coordinator over the library APIs.
- `AppSchema` fully insulates the application logic from raw UID generation and EAS payload structures.
- `PrivySigner` connects embedded wallets to the library via `EthereumRpcCaller` callback injections.
- `ExternalWalletSigner` routes external signature generation (MetaMask, etc.) through application callbacks back into the structured library types.
- `RuntimeNetworkConfig` is a lightweight immutable snapshot of already-resolved `SettingsService` values; it should not re-implement RPC precedence.
- `LocationProtocolApp` loads `SettingsService` once and passes a shared `RuntimeNetworkConfig` snapshot into `HomeScreen` for chain/RPC context.
- `AttestationService` read methods now depend only on the explicit HTTP RPC URL and no longer consult wallet RPC capabilities.
