import 'package:shared_preferences/shared_preferences.dart';

/// Persists dev/test settings via SharedPreferences.
///
/// Stores RPC URL, chain ID, and (optionally) a private key for
/// the dev/test private-key path. The private key is stored in
/// SharedPreferences which is NOT secure storage — this is acceptable
/// for a dev/test tool, not for production key management.
class SettingsService {
  static const _keyRpcUrl = 'settings_rpc_url';
  static const _keyChainId = 'settings_chain_id';
  static const _keyPrivateKey = 'settings_private_key';

  final SharedPreferences _prefs;

  SettingsService._(this._prefs);

  /// Creates a [SettingsService] backed by SharedPreferences.
  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService._(prefs);
  }

  String get rpcUrl => _prefs.getString(_keyRpcUrl) ?? '';

  Future<void> setRpcUrl(String url) => _prefs.setString(_keyRpcUrl, url);

  int get selectedChainId => _prefs.getInt(_keyChainId) ?? 11155111;

  Future<void> setSelectedChainId(int chainId) =>
      _prefs.setInt(_keyChainId, chainId);

  String get privateKeyHex => _prefs.getString(_keyPrivateKey) ?? '';

  Future<void> setPrivateKeyHex(String key) =>
      _prefs.setString(_keyPrivateKey, key);

  Future<void> clearPrivateKey() => _prefs.remove(_keyPrivateKey);
}
