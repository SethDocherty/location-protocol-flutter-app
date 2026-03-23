/// Provides Privy authentication state to the widget tree.
///
/// Wrap your [MaterialApp] (or a subtree) in [PrivyAuthProvider]:
///
/// ```dart
/// PrivyAuthProvider(
///   config: PrivyAuthConfig(appId: '...', clientId: '...'),
///   child: MaterialApp(...),
/// )
/// ```
///
/// Then access state anywhere below:
///
/// ```dart
/// final auth = PrivyAuthProvider.of(context);
/// if (auth.isAuthenticated) { ... }
/// ```
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:privy_flutter/privy_flutter.dart';

import 'privy_auth_config.dart';
import 'privy_manager.dart';

/// Holds the current authentication state exposed by [PrivyAuthProvider].
class PrivyAuthState extends ChangeNotifier {
  bool _isReady = false;
  bool _isAuthenticated = false;
  PrivyUser? _user;
  EmbeddedEthereumWallet? _wallet;
  /// The connected wallet address — populated from the embedded wallet when
  /// present, otherwise from the external wallet linked via SIWE.
  String? _walletAddress;
  String? _error;

  bool get isReady => _isReady;
  bool get isAuthenticated => _isAuthenticated;
  PrivyUser? get user => _user;
  EmbeddedEthereumWallet? get wallet => _wallet;
  String? get walletAddress => _walletAddress;
  String? get error => _error;

  void _update({
    bool? isReady,
    bool? isAuthenticated,
    PrivyUser? user,
    EmbeddedEthereumWallet? wallet,
    String? walletAddress,
    String? error,
    bool clearUser = false,
    bool clearWallet = false,
    bool clearWalletAddress = false,
    bool clearError = false,
  }) {
    bool changed = false;

    if (isReady != null && isReady != _isReady) {
      _isReady = isReady;
      changed = true;
    }
    if (isAuthenticated != null && isAuthenticated != _isAuthenticated) {
      _isAuthenticated = isAuthenticated;
      changed = true;
    }
    if (user != null && user != _user) {
      _user = user;
      changed = true;
    }
    if (clearUser && _user != null) {
      _user = null;
      changed = true;
    }
    if (wallet != null && wallet != _wallet) {
      _wallet = wallet;
      changed = true;
    }
    if (clearWallet && _wallet != null) {
      _wallet = null;
      changed = true;
    }
    if (walletAddress != null && walletAddress != _walletAddress) {
      _walletAddress = walletAddress;
      changed = true;
    }
    if (clearWalletAddress && _walletAddress != null) {
      _walletAddress = null;
      changed = true;
    }
    if (error != null && error != _error) {
      _error = error;
      changed = true;
    }
    if (clearError && _error != null) {
      _error = null;
      changed = true;
    }

    if (changed) notifyListeners();
  }

  /// Log the current user out.
  ///
  /// Auth state will update automatically via the [authStateStream] listener
  /// in [PrivyAuthProvider], but we also clear state immediately for
  /// responsive UI.
  Future<void> logout() async {
    await PrivyManager().logout();
    _update(
      isAuthenticated: false,
      clearUser: true,
      clearWallet: true,
      clearWalletAddress: true,
      clearError: true,
    );
  }
}

/// An [InheritedNotifier] that initializes Privy, listens to auth state
/// changes, and exposes [PrivyAuthState] to descendants.
class PrivyAuthProvider extends StatefulWidget {
  /// Configuration for Privy and the login modal.
  final PrivyAuthConfig config;

  /// The widget subtree that can access Privy auth state.
  final Widget child;

  const PrivyAuthProvider({
    super.key,
    required this.config,
    required this.child,
  });

  /// Retrieve the nearest [PrivyAuthState] from the widget tree.
  static PrivyAuthState of(BuildContext context, {bool listen = true}) {
    final _PrivyAuthInherited? provider = listen
        ? context.dependOnInheritedWidgetOfExactType<_PrivyAuthInherited>()
        : context.getElementForInheritedWidgetOfExactType<_PrivyAuthInherited>()
                ?.widget as _PrivyAuthInherited?;
    if (provider == null) {
      throw FlutterError(
        'PrivyAuthProvider.of() called without a PrivyAuthProvider ancestor.\n'
        'Wrap your app (or subtree) in PrivyAuthProvider.',
      );
    }
    return provider.state;
  }

  /// Retrieve config from nearest provider.
  static PrivyAuthConfig configOf(BuildContext context) {
    final widget =
        context.findAncestorWidgetOfExactType<PrivyAuthProvider>();
    if (widget == null) {
      throw FlutterError(
        'PrivyAuthProvider.configOf() called without a PrivyAuthProvider ancestor.',
      );
    }
    return widget.config;
  }

  @override
  State<PrivyAuthProvider> createState() => _PrivyAuthProviderState();
}

class _PrivyAuthProviderState extends State<PrivyAuthProvider> {
  final PrivyAuthState _state = PrivyAuthState();
  StreamSubscription<AuthState>? _authSub;

  /// Guards against concurrent embedded-wallet creation calls.
  ///
  /// Privy fires multiple auth-state events in quick succession after SIWE
  /// login (one per SDK lifecycle step). Without this flag each event would
  /// race to create a new embedded wallet before any of them sees the wallet
  /// in [PrivyUser.embeddedEthereumWallets], resulting in N duplicate wallets.
  bool _creatingWallet = false;

  @override
  void initState() {
    super.initState();
    _initializePrivy();
  }

  Future<void> _initializePrivy() async {
    try {
      final manager = PrivyManager();
      manager.initialize(widget.config);
      await manager.awaitReady();

      if (!mounted) return;

      _state._update(isReady: true);

      final currentAuth = manager.privy.currentAuthState;
      if (currentAuth is Authenticated) {
        await _handleAuthenticated(currentAuth.user);
      }

      _authSub = manager.privy.authStateStream.listen(_onAuthStateChanged);
    } catch (e) {
      debugPrint('PrivyAuthProvider: init error: $e');
      if (mounted) {
        _state._update(isReady: true, error: e.toString());
      }
    }
  }

  void _onAuthStateChanged(AuthState authState) {
    if (!mounted) return;

    if (authState is Authenticated) {
      _handleAuthenticated(authState.user);
    } else if (authState is Unauthenticated) {
      _state._update(
        isAuthenticated: false,
        clearUser: true,
        clearWallet: true,
        clearError: true,
      );
    }
  }

  Future<void> _handleAuthenticated(PrivyUser user) async {
    EmbeddedEthereumWallet? wallet;

    // Users who logged in via SIWE already have an external wallet — don't
    // auto-create an embedded wallet for them, even when autoCreateWallet is
    // true (mirroring the Privy dashboard "Create embedded wallets for all
    // users, even if they have linked external wallets" setting being off).
    final hasExternalWallet = user.linkedAccounts.any((a) => a.type == 'wallet');

    if (widget.config.autoCreateWallet && !hasExternalWallet) {
      wallet = await _ensureEmbeddedWallet(user);
    } else if (user.embeddedEthereumWallets.isNotEmpty) {
      wallet = user.embeddedEthereumWallets.first;
    }

    // Derive a display address from the embedded wallet or (for SIWE users)
    // from the ExternalWalletAccount in linkedAccounts.
    String? walletAddr = wallet?.address;
    if (walletAddr == null) {
      for (final acct in user.linkedAccounts) {
        if (acct is ExternalWalletAccount) {
          walletAddr = acct.address;
          break;
        }
      }
    }

    if (!mounted) return;

    _state._update(
      isAuthenticated: true,
      user: user,
      // Only update wallet field when we actually have one — don't clobber an
      // already-stored wallet with null when a re-entrant call returns early.
      wallet: wallet ?? _state.wallet,
      walletAddress: walletAddr ?? _state.walletAddress,
      clearError: true,
    );

    final effectiveWallet = wallet ?? _state.wallet;
    widget.config.onAuthenticated?.call(effectiveWallet?.address ?? walletAddr);
  }

  Future<EmbeddedEthereumWallet?> _ensureEmbeddedWallet(
    PrivyUser user,
  ) async {
    // Return the existing embedded wallet immediately if one already exists.
    if (user.embeddedEthereumWallets.isNotEmpty) {
      return user.embeddedEthereumWallets.first;
    }

    // If another auth-state event already kicked off wallet creation, don't
    // start a second one — just return whatever the current state already has.
    if (_creatingWallet) {
      debugPrint('PrivyAuthProvider: wallet creation already in progress, skipping duplicate request.');
      return _state.wallet;
    }

    _creatingWallet = true;
    try {
      debugPrint('PrivyAuthProvider: Requesting Ethereum wallet creation (allowAdditional: false)');
      final result = await user.createEthereumWallet();
      EmbeddedEthereumWallet? created;
      result.fold(
        onSuccess: (wallet) => created = wallet,
        onFailure: (error) {
          debugPrint('PrivyAuthProvider: wallet creation failed: ${error.message}');
        },
      );
      return created;
    } catch (e) {
      debugPrint('PrivyAuthProvider: wallet creation error: $e');
      return null;
    } finally {
      _creatingWallet = false;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PrivyAuthInherited(
      state: _state,
      child: widget.child,
    );
  }
}

class _PrivyAuthInherited extends InheritedNotifier<PrivyAuthState> {
  final PrivyAuthState state;

  const _PrivyAuthInherited({
    required this.state,
    required super.child,
  }) : super(notifier: state);
}
