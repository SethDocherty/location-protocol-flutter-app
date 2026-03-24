# Procedural Memory

- For Privy SDK integrations, verify package API directly from installed package sources before implementing plan snippets.
- When adding `.env` as Flutter asset, ensure a local `.env` file exists (even placeholder) or tests/build fail during asset bundling.
- Run targeted red-green tests first for new abstraction methods before full-suite regression.
- For auth-gated UI tests, prefer explicit provider-boundary assertions in smoke tests unless mocking the provider.
- Always enforce the `verification-before-completion` Iron Law strictly manually running verification commands *before* checking off lists or making success assertions. Do not substitute newly drafted test cases if the original plan provided explicit test blocks.
- When a widget loads `SettingsService.create()` from `initState`, set `SharedPreferences.setMockInitialValues({})` in widget tests to avoid hangs during `pumpAndSettle`.
- Gate onchain buttons by `AppWalletProvider.canSendTransactions` rather than `ConnectionType.privy` so external wallets can use the same runtime path.
- Keep RPC precedence logic in `SettingsService` only; any runtime config object should be a snapshot of already-resolved values, not a second resolver.
