import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';
import '../privy/privy_auth_provider.dart';
import '../services/reown_service.dart';
import '../protocol/privy_signer.dart';
import '../protocol/external_wallet_signer.dart';

enum ConnectionType { privy, external, privateKey, none }

class AppWalletProvider extends ChangeNotifier {
  final PrivyAuthState? _privyAuth;
  final ReownService? _reownService;

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

  void logout() {
    _privateKeyHex = null;
    _externalAddress = null;
    _privyAuth?.logout();
    notifyListeners();
  }

  Signer? getSigner(int targetChainId) {
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
              // Note: We need a BuildContext for Reown signTypedData usually.
              // This might need refinement if getSigner is called outside UI.
              throw UnimplementedError('External signing requires UI context or pre-configured service');
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

  Future<String?> sendTransaction(Map<String, dynamic> txRequest) async {
    if (connectionType == ConnectionType.privy && _privyAuth?.wallet != null) {
      // Implementation for Privy
      throw UnimplementedError('Privy transaction not yet wired');
    } else if (connectionType == ConnectionType.external && _reownService != null) {
      // Implementation for Reown
      throw UnimplementedError('Reown transaction not yet wired');
    }
    return null;
  }
}
