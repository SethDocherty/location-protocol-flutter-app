# Direct External Wallet Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make external wallet connection/signing work reliably by using direct Reown login in the modal, disconnecting SIWE from runtime UX, and unifying transaction/signing behavior through `AppWalletProvider`.

**Architecture:** Keep `Privy` support available but remove runtime SIWE entry points. Use `ReownService` as the single external-wallet transport, and make `AppWalletProvider` the source of truth for connection type, signer selection, and transaction routing. Persist only the last active non-private-key mode (`privy` or `external`) and keep private key state in-memory only.

**Tech Stack:** Flutter, Provider, Privy SDK, Reown AppKit, SharedPreferences.

---

## File Structure
- `lib/services/reown_service.dart` (MOD): Add explicit availability/initialization guards and safe behavior when `REOWN_PROJECT_ID` is missing.
- `lib/providers/app_wallet_provider.dart` (MOD): Normalize connection precedence, session mode persistence, and unified `sendTransaction` contract.
- `lib/settings/settings_service.dart` (MOD): Add `lastActiveWalletMode` persistence helpers (non-secret only) and remove stale private-key persistence comment text.
- `lib/main.dart` (MOD): Remove runtime SIWE login method exposure.
- `lib/privy/privy_auth_config.dart` (MOD): Remove SIWE from default login methods to avoid accidental re-exposure.
- `lib/privy/login_modal.dart` (MOD): Add direct “Connect External Wallet” selector path and disable gracefully when external wallet is unavailable.
- `lib/widgets/private_key_import_dialog.dart` (MOD): Keep import flow memory-only and verify no persistence side effects.
- `lib/privy/flows/siwe_flow.dart` (MOD/NO-DELETE): Keep file but disconnect runtime navigation into this flow.
- `lib/screens/home_screen.dart` (MOD): Gate on `canSendTransactions` and unified provider state instead of Privy-only checks.
- `lib/screens/onchain_attest_screen.dart` (MOD): Ensure provider tx call contract is used consistently.
- `lib/screens/register_schema_screen.dart` (MOD): Ensure provider tx call contract is used consistently.
- `lib/screens/timestamp_screen.dart` (MOD): Ensure provider tx call contract is used consistently.
- `test/providers/app_wallet_provider_test.dart` (MOD): Add tests for mode precedence and persistence semantics.
- `test/services/reown_service_test.dart` (NEW): Add tests for missing project ID and guarded call behavior.
- `test/privy/login_modal_test.dart` (NEW): Add selector tests for external connect visibility/disabled state and SIWE removal from runtime menu.
- `test/widgets/private_key_import_dialog_test.dart` (NEW): Verify private key import does not call persistence APIs.
- `test/screens/home_screen_auth_test.dart` (NEW): Add wallet-state gating tests for login CTA and onchain controls.

---

### Task 1: Harden ReownService Availability and Initialization

**Files:**
- Modify: `lib/services/reown_service.dart`
- Create: `test/services/reown_service_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/services/reown_service_test.dart` with focused behavior tests:
- Service reports unavailable when `REOWN_PROJECT_ID` is empty/missing.
- `connectAndGetAddress()` returns `null` when unavailable.
- `personalSign`, `signTypedData`, and `sendTransaction` throw `StateError('ReownService unavailable')` when unavailable (no `LateInitializationError`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/reown_service_test.dart`
Expected: FAIL with missing guards / uninitialized modal behavior.

- [ ] **Step 3: Write minimal implementation**

In `lib/services/reown_service.dart`:
- Add explicit fields/getters for availability and initialization.
- Make `initialize` idempotent and no-op safely when project ID is absent.
- Guard all public wallet operations behind readiness checks.
- Ensure no call path can touch uninitialized `appKitModal`.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/services/reown_service_test.dart`
Expected: PASS

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze lib/services/reown_service.dart test/services/reown_service_test.dart`
Expected: PASS

```bash
git add lib/services/reown_service.dart test/services/reown_service_test.dart
git commit -m "fix: harden reown service availability and init guards"
```

---

### Task 2: Normalize AppWalletProvider Session and Routing

**Files:**
- Modify: `lib/providers/app_wallet_provider.dart`
- Modify: `lib/settings/settings_service.dart`
- Modify: `test/providers/app_wallet_provider_test.dart`

- [ ] **Step 1: Write the failing tests**

Add tests in `test/providers/app_wallet_provider_test.dart`:
- last active mode (`privy`/`external`) is persisted and restored.
- private key remains in-memory only (not persisted).
- precedence resolves by last active mode when both privy-auth and external address exist.
- fallback precedence is deterministic when persisted mode is absent/invalid: prefer restored Privy auth, else connected external, else none.
- `sendTransaction` contract is deterministic by mode:
	- `privy`/`external`: returns tx hash string on success.
	- `privateKey`/`none`: throws `StateError('Transactions unavailable for current connection type')`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/app_wallet_provider_test.dart`
Expected: FAIL due to missing mode persistence / precedence / routing behavior.

- [ ] **Step 3: Write minimal implementation**

In `lib/settings/settings_service.dart`:
- Add non-secret key for `lastActiveWalletMode`.
- Add `get`/`set`/`clear` helpers for this key.
- Update stale service description text that still implies private-key persistence.

In `lib/providers/app_wallet_provider.dart`:
- Add load/save/clear of last active wallet mode.
- Keep private key ephemeral; never store private key in `SettingsService`.
- Ensure `connectionType`, `getSigner`, and `sendTransaction` are deterministic by active mode, including absent/invalid persisted mode fallback.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/providers/app_wallet_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze lib/providers/app_wallet_provider.dart lib/settings/settings_service.dart test/providers/app_wallet_provider_test.dart`
Expected: PASS

```bash
git add lib/providers/app_wallet_provider.dart lib/settings/settings_service.dart test/providers/app_wallet_provider_test.dart
git commit -m "feat: persist active wallet mode and normalize provider routing"
```

---

### Task 3: Disconnect SIWE from Runtime Login UX

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/privy/privy_auth_config.dart`
- Modify: `lib/privy/login_modal.dart`
- Modify: `lib/privy/flows/siwe_flow.dart` (only as needed to keep compile-safe, no deletion)
- Create: `test/privy/login_modal_test.dart`
- Create: `test/widgets/private_key_import_dialog_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/privy/login_modal_test.dart` with cases:
- Selector shows `Import Private Key` and `Connect External Wallet` options.
- SIWE runtime option is not shown in the active selector path.
- External connect option shows disabled/help state when Reown unavailable.

Create `test/widgets/private_key_import_dialog_test.dart` with cases:
- Dialog returns key to caller and does not call `SettingsService` persistence APIs.
- Cancel/empty submission does not modify provider state.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/privy/login_modal_test.dart`
Expected: FAIL while SIWE path still present and external direct option incomplete.

Run: `flutter test test/widgets/private_key_import_dialog_test.dart`
Expected: FAIL until dialog persistence coupling is removed/guarded.

- [ ] **Step 3: Write minimal implementation**

In `lib/main.dart`:
- Remove `LoginMethod.siwe` from runtime login methods list.

In `lib/privy/privy_auth_config.dart`:
- Remove `LoginMethod.siwe` from default login methods so other call sites cannot unintentionally re-enable SIWE.

In `lib/privy/login_modal.dart`:
- Add direct external connect action that calls `AppWalletProvider`/`ReownService` connect path.
- Keep private key import path as in-memory behavior.
- Remove runtime navigation into SIWE flow pages.

In `lib/widgets/private_key_import_dialog.dart`:
- Ensure submit path returns key to caller only and does not invoke any persistence service.

In `lib/privy/flows/siwe_flow.dart`:
- Keep file intact and compile-safe; do not delete.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/privy/login_modal_test.dart`
Expected: PASS

Run: `flutter test test/widgets/private_key_import_dialog_test.dart`
Expected: PASS

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze lib/main.dart lib/privy/privy_auth_config.dart lib/privy/login_modal.dart lib/privy/flows/siwe_flow.dart lib/widgets/private_key_import_dialog.dart test/privy/login_modal_test.dart test/widgets/private_key_import_dialog_test.dart`
Expected: PASS

```bash
git add lib/main.dart lib/privy/privy_auth_config.dart lib/privy/login_modal.dart lib/privy/flows/siwe_flow.dart lib/widgets/private_key_import_dialog.dart test/privy/login_modal_test.dart test/widgets/private_key_import_dialog_test.dart
git commit -m "refactor: use direct external wallet login and disconnect runtime siwe path"
```

---

### Task 4: Align Home and Onchain Screens with Unified Wallet Provider

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/onchain_attest_screen.dart`
- Modify: `lib/screens/register_schema_screen.dart`
- Modify: `lib/screens/timestamp_screen.dart`
- Create: `test/screens/home_screen_auth_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/screens/home_screen_auth_test.dart` to verify:
- disconnected state shows login CTA.
- connected external state can access unified offchain signing path.
- onchain action visibility is based on `canSendTransactions`, not Privy-only checks.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/home_screen_auth_test.dart`
Expected: FAIL while home gating still Privy-specific.

- [ ] **Step 3: Write minimal implementation**

In `lib/screens/home_screen.dart`:
- Replace Privy-only onchain gating with provider capability checks.
- Keep single offchain sign path through `walletProvider.getSigner(...)`.

In onchain screens:
- Ensure all transaction submissions call `context.read<AppWalletProvider>().sendTransaction(...)` with identical contract handling:
	- success: non-empty tx hash is displayed.
	- provider `StateError`: surface user-friendly message and do not crash.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/screens/home_screen_auth_test.dart`
Expected: PASS

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze lib/screens/home_screen.dart lib/screens/onchain_attest_screen.dart lib/screens/register_schema_screen.dart lib/screens/timestamp_screen.dart test/screens/home_screen_auth_test.dart`
Expected: PASS

```bash
git add lib/screens/home_screen.dart lib/screens/onchain_attest_screen.dart lib/screens/register_schema_screen.dart lib/screens/timestamp_screen.dart test/screens/home_screen_auth_test.dart
git commit -m "fix: align home and onchain flows with unified wallet provider"
```

---

### Task 5: End-to-End Verification and Plan Status Update

**Files:**
- Modify: `docs/spec/plans/2026-03-23-offchain-operations-plan.md`
- Modify: `docs/spec/plans/2026-03-23-direct-external-wallet-implementation-plan.md` (checklist updates only)

- [ ] **Step 1: Run full static analysis**

Run: `flutter analyze`
Expected: PASS

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: PASS

- [ ] **Step 3: Update status checkboxes and notes**

In `docs/spec/plans/2026-03-23-offchain-operations-plan.md`:
- Mark completed tasks that are truly done.
- Add note that runtime SIWE path is intentionally disconnected in favor of direct Reown external flow.

In this plan file:
- Mark any completed task steps and verification artifacts.

- [ ] **Step 4: Commit verification + docs updates**

```bash
git add docs/spec/plans/2026-03-23-offchain-operations-plan.md docs/spec/plans/2026-03-23-direct-external-wallet-implementation-plan.md
git commit -m "docs: reconcile offchain redesign status and direct external wallet plan"
```

- [ ] **Step 5: Final gate before handoff/merge**

If `flutter analyze` or `flutter test` failed in Task 5 steps 1-2:
- Fix only scoped issues from Tasks 1-4.
- Amend relevant task commit(s) or add one scoped fixup commit.
- Re-run Task 5 steps 1-2 until PASS.

---

## Execution Notes
- Do not delete SIWE files during this implementation; only remove runtime entry points.
- Do not persist private keys anywhere (memory-only).
- Keep changes minimal and scoped to this behavior correction; avoid unrelated refactors.
