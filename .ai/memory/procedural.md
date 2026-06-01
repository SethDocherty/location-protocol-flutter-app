# Procedural Memory

- For Privy SDK integrations, verify package API directly from installed package sources before implementing plan snippets.
- When adding `.env` as Flutter asset, ensure a local `.env` file exists (even placeholder) or tests/build fail during asset bundling.
- Run targeted red-green tests first for new abstraction methods before full-suite regression.
- For auth-gated UI tests, prefer explicit provider-boundary assertions in smoke tests unless mocking the provider.
- Always enforce the `verification-before-completion` Iron Law strictly manually running verification commands *before* checking off lists or making success assertions. Do not substitute newly drafted test cases if the original plan provided explicit test blocks.
- When a widget loads `SettingsService.create()` from `initState`, set `SharedPreferences.setMockInitialValues({})` in widget tests to avoid hangs during `pumpAndSettle`.
- Gate onchain buttons by `AppWalletProvider.canSendTransactions` rather than `ConnectionType.privy` so external wallets can use the same runtime path.
- Keep RPC precedence logic in `SettingsService` only; any runtime config object should be a snapshot of already-resolved values, not a second resolver.
- When making RPC routing explicit, update all `AttestationService` constructors in tests and widget helpers together so analyzer output stays clean after the signature change.
- Prefer a single settings-derived runtime snapshot at the app boundary; refresh it from the owning state object rather than reloading settings inside screens.
- When a screen submits transactions through `AppWalletProvider`, pass the widget `BuildContext` for external-wallet support; omission can work for embedded wallets but breaks external wallet flows.
- For `privy_flutter 0.4.x` embedded wallets, rewrite EIP-712 `primaryType` to `primary_type` before JSON-encoding typed-data RPC params; the Flutter bridge/native handlers still accept string params for `eth_signTypedData_v4` and `eth_sendTransaction`.
- For `reown_appkit 1.8.x`, pass `eth_signTypedData_v4` typed data as the current map payload shape and route target networks with CAIP-2 chain IDs (`eip155:<id>`), using `selectChain(..., switchChain: true)` when the session chain differs.
- For app-owned EAS receipt polling, mirror upstream parsing rules: check receipt `status` for reverts before log parsing, then require both the expected contract address and the event topic (`Attested` or `Timestamped`) before extracting fields from logs or topics.
- When wallet-flow read helpers must remain app-owned, isolate raw HTTP JSON-RPC transport and typed receipt decoding in a small adapter that returns upstream `TransactionReceipt` / `TransactionLog` models; keep business-level interpretation in `AttestationService`.
- For Reown transport boundaries, prefer a tiny modal adapter seam over direct `ReownAppKitModal` calls so typed-data and transaction request shapes can be regression-tested without changing UI call sites.
