# Semantic Memory

- `PrivyAuthProvider` is the app-level auth boundary and exposes `PrivyAuthState` via `InheritedNotifier`.
- `PrivyManager` owns singleton SDK initialization and readiness wait using `getAuthState()` (not deprecated `awaitReady`).
- `AttestationSigner` decouples EIP-712 signing from key material/backend.
- `LocalKeySigner` preserves deterministic local signing for tests and compatibility.
- `PrivyWalletSigner` signs digest via embedded wallet provider RPC and returns `MsgSignature`.
- `EIP712Signer.signLocationAttestationWith(...)` is the async abstraction entrypoint; existing sync method remains intact.
