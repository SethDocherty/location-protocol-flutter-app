# Privy Wallet Authentication Integration Walkthrough

## Summary
This implementation integrates Privy authentication and embedded-wallet signing into the app while preserving existing EIP-712 sync signing behavior for compatibility.

## Completed Scope

### Platform and setup
- Added `privy_flutter` and `flutter_dotenv` dependencies.
- Added `.env` asset loading and `.env` gitignore rule.
- Added `.env.example` with required keys.
- Updated Android requirements for Privy SDK:
  - `minSdk` to 27
  - Kotlin to 2.1.0

### Reusable auth modal module (`lib/src/privy_auth_modal`)
- Added `PrivyAuthConfig` + `LoginMethod` + appearance options.
- Added `PrivyManager` singleton wrapper for SDK init and lifecycle.
- Added `PrivyAuthProvider` with:
  - readiness/auth state tracking
  - wallet auto-creation behavior
  - stream-based auth updates
  - `logout()` on `PrivyAuthState`
- Added reusable login UI:
  - `LoginMethodButton`
  - `OtpInputView`
- Added auth flows:
  - SMS
  - Email
  - OAuth (SDK-correct: uses `privy.oAuth.login(..., appUrlScheme: ...)`)
  - SIWE placeholder (see note below)
- Added modal entrypoint `showPrivyLoginModal` and public barrel export.

### Signing abstraction (`lib/src/eas`)
- Added `AttestationSigner` interface.
- Added `LocalKeySigner` implementation and dedicated tests.
- Added async `EIP712Signer.signLocationAttestationWith(...)`.
- Added `PrivyWalletSigner` using wallet provider RPC (`personal_sign`).

### App integration
- Updated `main.dart` to load dotenv and wrap app with `PrivyAuthProvider`.
- Updated `HomeScreen` to auth-gated UX:
  - unauthenticated: login button
  - authenticated: sign/verify actions + logout
- Updated `SignScreen` to accept `AttestationSigner` and async signing.
- Removed legacy local wallet path:
  - deleted `lib/src/wallet/attestation_wallet.dart`
  - deleted `lib/screens/wallet_screen.dart`
  - removed `flutter_secure_storage` dependency
- Updated widget smoke test for provider-gated HomeScreen.

## TDD and verification
- Added red-green cycle for signer abstraction:
  - `test/attestation_signer_test.dart` introduced first (failed), then implementation added.
- Added red-green cycle for async signing path:
  - async tests added to `test/eip712_signer_test.dart` first (failed), then API implemented.
- Verification run outcomes:
  - `flutter analyze` passes.
  - `flutter test` passes.
  - `flutter build apk --debug` succeeds (`build/app/outputs/flutter-apk/app-debug.apk`).

## Important implementation notes
- OAuth requires `oauthAppUrlScheme` for current `privy_flutter` API and is wired via `PrivyAuthConfig.oauthAppUrlScheme`.
- SIWE in `privy_flutter 0.4.0` does not expose one-step login; it requires generate-message + external signature + login call. Current implementation intentionally provides a visible placeholder in `SiweFlow` until callback-driven signing orchestration is added.
- `PrivyWalletSigner` currently uses `personal_sign`; production validation should confirm recovered signer correctness. If recovery mismatches digest signing, switch to `eth_sign` (or `eth_signTypedData_v4` fallback).

## Runtime credentials needed
Populate local `.env` before full auth runtime testing:
- `PRIVY_APP_ID`
- `PRIVY_CLIENT_ID`
- `PRIVY_OAUTH_APP_URL_SCHEME` (required for OAuth providers)

## iOS note
iOS deployment/SPM steps were deferred in this Windows session and should be completed/verified on macOS.
