import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:location_protocol/location_protocol.dart';
import '../privy/privy_auth_provider.dart';
import '../services/reown_service.dart';
import '../protocol/privy_signer.dart';
import '../protocol/external_wallet_signer.dart';

enum ConnectionType { privy, external, privateKey, none }

class AppWalletProvider extends ChangeNotifier {
  final PrivyAuthState? _privyAuth;
  final ReownService? _reownService;

  PrivyAuthState? get privyAuth => _privyAuth;

  String? _privateKeyHex;
  String? _externalAddress;

  AppWalletProvider({
    PrivyAuthState? privyAuth,
    ReownService? reownService,
  })  : _privyAuth = privyAuth,
        _reownService = reownService {
    _privyAuth?.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _privyAuth?.removeListener(notifyListeners);
    super.dispose();
  }

  ConnectionType get connectionType {
    if (_privyAuth?.isAuthenticated == true) return ConnectionType.privy;
    if (_externalAddress != null) return ConnectionType.external;
    if (_privateKeyHex != null) return ConnectionType.privateKey;
    return ConnectionType.none;
  }

  bool get isConnected => connectionType != ConnectionType.none;

  bool get canSendTransactions =>
      connectionType == ConnectionType.privy ||
      connectionType == ConnectionType.external;

  String? get walletAddress {
    switch (connectionType) {
      case ConnectionType.privy:
        return _privyAuth?.walletAddress;
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

  void setPrivateKey(String key) {
    _privateKeyHex = key;
    _externalAddress = null;
    // If we're setting a private key, we likely want to bypass Privy if it was connected
    // but usually user would logout first. For now, we just prioritize based on connectionType getter.
    notifyListeners();
  }

  void setExternalAddress(String address) {
    _externalAddress = address;
    _privateKeyHex = null;
    notifyListeners();
  }

  Future<void> connectExternal(BuildContext context) async {
    if (_reownService == null) return;
    final address = await _reownService.connectAndGetAddress();
    if (address != null && address.isNotEmpty) {
      setExternalAddress(address);
    }
  }

  void logout() {
    _privateKeyHex = null;
    _externalAddress = null;
    _privyAuth?.logout();
    notifyListeners();
  }

  void disconnect() => logout();

  Signer? getSigner(BuildContext context, int targetChainId) {
    switch (connectionType) {
      case ConnectionType.privy:
        if (_privyAuth?.wallet != null) {
          return PrivySigner.fromWallet(_privyAuth!.wallet!);
        }
        return null;
      case ConnectionType.external:
        if (_externalAddress != null && _reownService != null) {
          return ExternalWalletSigner(
            walletAddress: _externalAddress!,
            onSignTypedData: (typedData) async {
              return await _reownService.signTypedData(context, typedData);
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

  Future<String?> sendTransaction(Map<String, dynamic> txRequest, {BuildContext? context}) async {
    final wallet = _privyAuth?.wallet;
    if (connectionType == ConnectionType.privy && wallet != null) {
      final result = await wallet.provider.request(
        EthereumRpcRequest(
          method: 'eth_sendTransaction',
          params: [jsonEncode(txRequest)],
        ),
      );
      String? hash;
      result.fold(
        onSuccess: (r) => hash = r.data,
        onFailure: (e) => throw Exception('Privy transaction failed: ${e.message}'),
      );
      return hash;
    } else if (connectionType == ConnectionType.external && _reownService != null && context != null) {
      return await _reownService.sendTransaction(context, txRequest);
    }
    return null;
  }
}
