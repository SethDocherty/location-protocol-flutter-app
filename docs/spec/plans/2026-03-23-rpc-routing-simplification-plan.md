# RPC Routing Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every blockchain read use a single resolved RPC endpoint from `.env` or settings, while removing duplicated RPC/chain bookkeeping from screens and protocol services.

**Architecture:** Keep `SettingsService` as the only persistence layer for chain and RPC preferences. Add a tiny immutable runtime config snapshot that copies the already-resolved values from `SettingsService`, and pass that snapshot across the app boundary instead of letting screens or services re-derive chain/RPC values independently. Refactor `AttestationService` so read-only RPC calls always go through the resolved HTTP RPC URL, while wallet providers remain responsible only for signing and transaction submission.

**Tech Stack:** Flutter, Provider, SharedPreferences, flutter_dotenv, http, Privy SDK, Reown AppKit.

---

## File Structure

- `lib/services/runtime_network_config.dart` (NEW): Immutable runtime snapshot built from `SettingsService` values.
- `test/services/runtime_network_config_test.dart` (NEW): Unit tests that the snapshot mirrors the already-resolved settings values.
- `lib/protocol/attestation_service.dart` (MOD): Read-only RPC path uses the resolved HTTP RPC URL directly; removes wallet-RPC fallback for reads.
- `test/protocol/attestation_service_test.dart` (MOD): Verifies read methods use the configured RPC endpoint and do not depend on wallet RPC.
- `lib/screens/home_screen.dart` (MOD): Stops holding a local `_rpcUrl`; loads one runtime config snapshot and passes it to service constructors.
- `lib/main.dart` (MOD): Load settings once and construct one shared runtime snapshot for app wiring.
- `lib/providers/app_wallet_provider.dart` (MOD, if needed): Keep wallet concerns separate from read-RPC resolution; only adjust constructor wiring if a new config snapshot is required.
- `test/screens/home_screen_auth_test.dart` (MOD): Update expectations for the revised settings/config wiring.
- `test/widget_test.dart` (MOD, if needed): Keep smoke tests aligned with any new provider or snapshot wiring.

---

### Task 1: Add a tiny runtime network snapshot

**Files:**
- Create: `lib/services/runtime_network_config.dart`
- Create: `test/services/runtime_network_config_test.dart`

- [ ] **Step 1: Write the failing test**

Create tests that prove the snapshot is an immutable value object built from the already-resolved `SettingsService` values and that it carries the selected chain ID and effective RPC URL through unchanged.

Keep precedence coverage in `test/settings/settings_service_test.dart`; this new test should only verify the snapshot shape and copy behavior.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/runtime_network_config_test.dart`

Expected: FAIL because `RuntimeNetworkConfig` and its resolver do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Add a small immutable model such as `RuntimeNetworkConfig` with fields like:

- `int selectedChainId`
- `String rpcUrl`
- `bool get hasRpcUrl`

Add a factory such as `RuntimeNetworkConfig.fromSettings(SettingsService service)` that copies the already-resolved values from `SettingsService`. Do not re-encode `.env`/Infura/manual precedence here, and do not add widget dependencies or a new global provider; keep this file self-contained and easy to unit test.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/services/runtime_network_config_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/runtime_network_config.dart test/services/runtime_network_config_test.dart
git commit -m "feat: add runtime network config snapshot"
```

---

### Task 2: Make read-only RPC explicit in `AttestationService`

**Files:**
- Modify: `lib/protocol/attestation_service.dart`
- Modify: `test/protocol/attestation_service_test.dart`

- [ ] **Step 1: Write the failing test**

Add or update tests so that:

- `getSchemaRecord()` uses the configured HTTP RPC URL
- `getTimestamp()` uses the configured HTTP RPC URL
- `getTransactionReceipt()` uses the configured HTTP RPC URL
- `waitForAttestationUid()` still succeeds using the configured HTTP RPC URL path
- read-only paths do not depend on the signer's wallet RPC capabilities

Use a mock HTTP client where appropriate and keep the test asserting the exact RPC URL used.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/protocol/attestation_service_test.dart`

Expected: FAIL because read methods still route through wallet RPC fallback behavior.

- [ ] **Step 3: Write minimal implementation**

Refactor `AttestationService` so read-only calls use one explicit RPC input instead of trying the signer first. Rename the constructor field from a vague fallback name to something that reflects its actual role, such as `readRpcUrl` or `rpcUrl`.

Keep write behavior unchanged:

- offchain signing still uses `Signer`
- onchain transaction submission still uses wallet/provider wiring outside `AttestationService`
- receipt polling and `eth_call` must go through the configured RPC URL only

Remove duplicated fallback branching that makes the read path depend on Privy wallet RPC.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/protocol/attestation_service_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/protocol/attestation_service.dart test/protocol/attestation_service_test.dart
git commit -m "refactor: route protocol reads through explicit rpc url"
```

---

### Task 3: Thread one config snapshot through the app boundary

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/providers/app_wallet_provider.dart` only if constructor wiring needs a new input
- Modify: `test/screens/home_screen_auth_test.dart`

- [ ] **Step 1: Write the failing test**

Update the HomeScreen tests so they assert the screen still renders the same wallet actions, but no longer relies on a local `_rpcUrl` field or duplicated settings load state.

If a helper is needed, add one test that verifies the app can construct a service from one runtime config snapshot instead of separate chain/RPC state.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/screens/home_screen_auth_test.dart`

Expected: FAIL because HomeScreen still owns its own RPC state and service wiring.

- [ ] **Step 3: Write minimal implementation**

Update the app composition so settings are loaded once into a runtime snapshot and then reused for screen/service construction.

Use one explicit injection path from `main.dart`: create `SettingsService` once, build one `RuntimeNetworkConfig` snapshot from it, and pass that same snapshot into every place that needs chain/RPC context.

In `HomeScreen`:

- remove `_rpcUrl`
- stop re-deriving RPC from separate local state
- accept the runtime snapshot in the constructor instead of reloading settings inside the widget
- use the snapshot to create `AttestationService`
- keep `_chainId` and RPC values aligned from the same source

Keep `AppWalletProvider` wallet-centric. Do not move RPC resolution logic into the wallet provider unless a test proves it is required.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/screens/home_screen_auth_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/screens/home_screen.dart lib/providers/app_wallet_provider.dart test/screens/home_screen_auth_test.dart
git commit -m "refactor: centralize runtime network config wiring"
```

---

### Task 4: Clean up remaining caller duplication

**Files:**
- Modify: `lib/screens/onchain_attest_screen.dart` if needed
- Modify: `lib/screens/register_schema_screen.dart` if needed
- Modify: `lib/screens/timestamp_screen.dart` if needed
- Modify: `test/widget_test.dart` if needed
- Modify: `test/screens/onchain_attest_screen_test.dart` if needed

- [ ] **Step 1: Write or review the failing test**

Look for any tests or callers that still pass both chain and RPC state independently. Update them so they use the new snapshot-based wiring or explicit read-RPC input.

- [ ] **Step 2: Run the tests to verify what still fails**

Run the smallest targeted set that covers the modified callers, then expand if necessary.

Expected: Any failures should point only to stale constructor arguments or duplicated settings plumbing.

- [ ] **Step 3: Write minimal implementation**

Remove leftover duplicated RPC/chain loading from screens and helpers. Prefer:

- one snapshot source
- explicit constructor parameters at the edge
- no hidden state in widgets

Do not broaden the abstraction if a direct parameter keeps the coupling lower.

- [ ] **Step 4: Run the tests to verify they pass**

Run the targeted widget and unit tests for the affected screens.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/onchain_attest_screen.dart lib/screens/register_schema_screen.dart lib/screens/timestamp_screen.dart test/widget_test.dart test/screens/onchain_attest_screen_test.dart
git commit -m "refactor: remove duplicated rpc wiring from screens"
```

---

### Task 5: Full regression verification

**Files:**
- No code changes expected unless a regression appears.

- [ ] **Step 1: Run focused tests**

Run the following, in this order:

- `flutter test test/services/runtime_network_config_test.dart`
- `flutter test test/protocol/attestation_service_test.dart`
- `flutter test test/screens/home_screen_auth_test.dart`

Expected: PASS.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`

Expected: PASS with no new warnings or errors.

- [ ] **Step 3: Commit any final cleanup**

If any tiny cleanup is needed after verification, commit it separately so the history stays reviewable.

```bash
git add -A
git commit -m "chore: finalize rpc routing simplification"
```
