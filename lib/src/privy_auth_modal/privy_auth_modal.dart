/// Privy Auth Modal — a drop-in authentication component for Flutter apps.
///
/// ## Quick Start
///
/// 1. Wrap your app:
/// ```dart
/// PrivyAuthProvider(
///   config: PrivyAuthConfig(
///     appId: 'your-app-id',
///     clientId: 'your-client-id',
///   ),
///   child: MaterialApp(...),
/// )
/// ```
///
/// 2. Open the login modal:
/// ```dart
/// final user = await showPrivyLoginModal(context);
/// ```
///
/// 3. Read auth state anywhere:
/// ```dart
/// final auth = PrivyAuthProvider.of(context);
/// if (auth.isAuthenticated) {
///   print(auth.wallet?.address);
/// }
/// ```
library privy_auth_modal;

export 'login_modal.dart' show showPrivyLoginModal;
export 'privy_auth_config.dart'
    show PrivyAuthAppearance, PrivyAuthConfig, LoginMethod;
export 'privy_auth_provider.dart' show PrivyAuthProvider, PrivyAuthState;
export 'package:privy_flutter/privy_flutter.dart'
    show AuthState, EmbeddedEthereumWallet, PrivyUser;
