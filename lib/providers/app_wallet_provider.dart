import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:privy_flutter/privy_flutter.dart';

import '../protocol/external_wallet_signer.dart';
import '../protocol/privy_signer.dart';
import '../privy/privy_auth_provider.dart';
import '../services/reown_service.dart';
import '../settings/settings_service.dart';

enum ConnectionType { privy, external, privateKey, none }

enum _PersistedWalletMode { privy, external }

_PersistedWalletMode? _parsePersistedWalletMode(String? value) {
  switch (value) {
    case 'privy':
      return _PersistedWalletMode.privy;
    case 'external':
      return _PersistedWalletMode.external;
    default:
      return null;
  }
}

class AppWalletProvider extends ChangeNotifier {
  final PrivyAuthState? _privyAuth;
  final ReownService? _reownService;
  final Future<SettingsService> _settingsServiceFuture;

  SettingsService? _settingsService;
  String? _privateKeyHex;
  String? _externalAddress;

  Future<void> get ready => _readyFuture;
  late final Future<void> _readyFuture;

  PrivyAuthState? get privyAuth => _privyAuth;

  String? get lastActiveWalletMode => _settingsService?.lastActiveWalletMode;

  AppWalletProvider({
    PrivyAuthState? privyAuth,
    ReownService? reownService,
    SettingsService? settingsService,
  })  : _privyAuth = privyAuth,
        _reownService = reownService,
        _settingsServiceFuture = settingsService != null
            ? Future.value(settingsService)
            : SettingsService.create() {
    _privyAuth?.addListener(_handlePrivyAuthChanged);
    _readyFuture = _loadPersistedState();
  }

  @override
  void dispose() {
    _privyAuth?.removeListener(_handlePrivyAuthChanged);
    super.dispose();
  }

  Future<void> _loadPersistedState() async {
    _settingsService = await _settingsServiceFuture;
    notifyListeners();
  }

  Future<void> _persistActiveMode(ConnectionType type) async {
    final service = _settingsService ?? await _settingsServiceFuture;
    _settingsService = service;

    switch (type) {
      case ConnectionType.privy:
        await service.setLastActiveWalletMode('privy');
        return;
      case ConnectionType.external:
        await service.setLastActiveWalletMode('external');
        return;
      case ConnectionType.privateKey:
      case ConnectionType.none:
        return;
    }
  }

  Future<void> _clearPersistedMode() async {
    final service = _settingsService ?? await _settingsServiceFuture;
    _settingsService = service;
    await service.clearLastActiveWalletMode();
  }

  void _handlePrivyAuthChanged() {
    if (_privyAuth?.isAuthenticated == true &&
        _privateKeyHex == null &&
        _externalAddress == null) {
      unawaited(_persistActiveMode(ConnectionType.privy));
    }
    notifyListeners();
  }

  bool get _hasPrivyConnection => _privyAuth?.isAuthenticated == true;

  bool get _hasExternalConnection => _externalAddress != null;

  bool get _hasPrivateKey => _privateKeyHex != null;

  ConnectionType get connectionType {
    if (_hasPrivateKey) {
      return ConnectionType.privateKey;
    }

    final persistedMode = _parsePersistedWalletMode(
      _settingsService?.lastActiveWalletMode,
    );

    switch (persistedMode) {
      case _PersistedWalletMode.privy:
        if (_hasPrivyConnection) return ConnectionType.privy;
        if (_hasExternalConnection) return ConnectionType.external;
        return ConnectionType.none;
      case _PersistedWalletMode.external:
        if (_hasExternalConnection) return ConnectionType.external;
        if (_hasPrivyConnection) return ConnectionType.privy;
        return ConnectionType.none;
      case null:
        if (_hasPrivyConnection) return ConnectionType.privy;
        if (_hasExternalConnection) return ConnectionType.external;
        return ConnectionType.none;
    }
  }

  bool get isConnected => connectionType != ConnectionType.none;

  bool get canSendTransactions {
    switch (connectionType) {
      case ConnectionType.privy:
        return _privyAuth?.wallet != null;
      case ConnectionType.external:
        return _externalAddress != null && _reownService != null;
      case ConnectionType.privateKey:
      case ConnectionType.none:
        return false;
    }
  }

  String? get walletAddress {
    switch (connectionType) {
      case ConnectionType.privy:
        return _privyAuth?.wallet?.address ?? _privyAuth?.walletAddress;
      case ConnectionType.external:
        return _externalAddress;
      case ConnectionType.privateKey:
        if (_privateKeyHex != null) {
          return LocalKeySigner(privateKeyHex: _privateKeyHex!).address;
        }
        return null;
      case ConnectionType.none:
        return null;
    }
  }

  Future<void> setPrivateKey(String key) async {
    _privateKeyHex = key;
    _externalAddress = null;
    notifyListeners();
  }

  Future<void> setExternalAddress(String address) async {
    _externalAddress = address;
    _privateKeyHex = null;
    await _persistActiveMode(ConnectionType.external);
    notifyListeners();
  }

  Future<void> connectExternal(BuildContext context) async {
    if (_reownService == null) return;
    await _reownService.initialize(context);
    final address = await _reownService.connectAndGetAddress();
    if (address != null && address.isNotEmpty) {
      await setExternalAddress(address);
    }
  }

  Future<void> logout() async {
    _privateKeyHex = null;
    _externalAddress = null;
    await _clearPersistedMode();
    await _privyAuth?.logout();
    notifyListeners();
  }

  Future<void> disconnect() => logout();

  Signer? getSigner(BuildContext context, int targetChainId) {
    switch (connectionType) {
      case ConnectionType.privy:
        if (_privyAuth?.wallet != null) {
          return PrivySigner.fromWallet(_privyAuth!.wallet!);
        }
        return null;
      case ConnectionType.external:
        final address = _externalAddress;
        final reownService = _reownService;
        if (address != null && reownService != null) {
          return ExternalWalletSigner(
            walletAddress: address,
            onSignTypedData: (typedData) async {
              return reownService.signTypedData(
                context,
                typedData,
                targetChainId: 'eip155:$targetChainId',
              );
            },
          );
        }
        return null;
      case ConnectionType.privateKey:
        if (_privateKeyHex != null) {
          return LocalKeySigner(privateKeyHex: _privateKeyHex!);
        }
        return null;
      case ConnectionType.none:
        return null;
    }
  }

  Future<String?> sendTransaction(
    Map<String, dynamic> txRequest, {
    BuildContext? context,
  }) async {
    switch (connectionType) {
      case ConnectionType.privy:
        final wallet = _privyAuth?.wallet;
        if (wallet == null) {
          throw StateError('Transactions unavailable for current connection type');
        }

        final result = await wallet.provider.request(
          EthereumRpcRequest(
            method: 'eth_sendTransaction',
            params: [jsonEncode(txRequest)],
          ),
        );

        String? hash;
        result.fold(
          onSuccess: (r) => hash = r.data,
          onFailure: (_) {
            throw StateError('Transactions unavailable for current connection type');
          },
        );
        return hash;
      case ConnectionType.external:
        if (_reownService == null || context == null) {
          throw StateError('Transactions unavailable for current connection type');
        }
        final requestedChainId = txRequest['chainId'];
        String? targetChainId;
        if (requestedChainId is String && requestedChainId.startsWith('0x')) {
          final chainIdInt = int.tryParse(requestedChainId.substring(2), radix: 16);
          if (chainIdInt != null) {
            targetChainId = 'eip155:$chainIdInt';
          }
        }
        return _reownService.sendTransaction(
          context,
          txRequest,
          targetChainId: targetChainId,
        );
      case ConnectionType.privateKey:
      case ConnectionType.none:
        throw StateError('Transactions unavailable for current connection type');
    }
  }
}
