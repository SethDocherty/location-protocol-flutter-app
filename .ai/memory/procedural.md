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
