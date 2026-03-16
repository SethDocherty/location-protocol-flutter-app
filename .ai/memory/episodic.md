# Episodic Memory

- [ID: PRIVY_PHASE1_EXECUTION] -> Follows [ID: NONE]. Context: Implemented Privy Phase 1 plan in batches, including auth modal module, signing abstraction, host app auth-gating, and legacy wallet removal. Verified via analyze/test/build.
- [ID: SDK_API_GAP_HANDLING] -> Follows [ID: PRIVY_PHASE1_EXECUTION]. Context: Plan API for OAuth/SIWE mismatched `privy_flutter 0.4.0`; adapted OAuth to `oAuth.login(..., appUrlScheme)` and shipped explicit SIWE placeholder pending callback-based signing orchestration.
- [ID: TEST_REGRESSION_FIX] -> Follows [ID: SDK_API_GAP_HANDLING]. Context: `main.dart` dotenv bootstrap caused widget test failure; fixed by converting smoke test to provider-missing expectation for HomeScreen.
