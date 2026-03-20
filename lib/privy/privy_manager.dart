/// Internal singleton that manages the Privy SDK lifecycle.
///
/// This is internal to the privy module — not exported
/// through the barrel file. Consumers interact via [PrivyAuthProvider].
library;

import 'package:flutter/foundation.dart';
import 'package:privy_flutter/privy_flutter.dart';

import 'privy_auth_config.dart';

/// Singleton wrapper around the Privy Flutter SDK.
///
/// Ensures a single [Privy] instance across the app lifetime,
/// as required by the Privy SDK documentation.
class PrivyManager {
  PrivyManager._();

  static final PrivyManager _instance = PrivyManager._();
  factory PrivyManager() => _instance;

  Privy? _privy;

  /// The initialized Privy SDK instance.
  ///
  /// Throws if accessed before [initialize] is called.
  Privy get privy {
    if (_privy == null) {
      throw StateError(
        'PrivyManager has not been initialized. '
        'Wrap your app in PrivyAuthProvider first.',
      );
    }
    return _privy!;
  }

  /// Whether the SDK has been initialized.
  bool get isInitialized => _privy != null;

  /// Initialize the Privy SDK with the given config.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  void initialize(PrivyAuthConfig config) {
    if (_privy != null) return;

    try {
      final privyConfig = PrivyConfig(
        appId: config.appId,
        appClientId: config.clientId,
        logLevel: kDebugMode ? PrivyLogLevel.debug : PrivyLogLevel.none,
      );
      _privy = Privy.init(config: privyConfig);
      debugPrint('PrivyManager: SDK initialized');
    } catch (e, stack) {
      debugPrint('PrivyManager: initialization failed: $e\n$stack');
      rethrow;
    }
  }

  /// Wait for the SDK to finish its startup checks (token refresh,
  /// wallet state, etc.).
  Future<void> awaitReady() async {
    await privy.getAuthState();
  }

  /// Log the current user out and clear session state.
  Future<void> logout() async {
    await privy.logout();
  }
}
