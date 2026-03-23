import 'package:shared_preferences/shared_preferences.dart';

/// Persists dev/test settings via SharedPreferences.
///
/// Stores RPC URL, chain ID, Infura configuration, and the last active
/// non-secret wallet mode used by the app.
class SettingsService {
  static const _keyRpcUrl = 'settings_rpc_url';
  static const _keyChainId = 'settings_chain_id';

  static const _keyInfuraApiKey = 'settings_infura_api_key';
  static const _keyLastActiveWalletMode = 'settings_last_active_wallet_mode';

  static const Map<int, String> _infuraSubdomains = {
    1: 'mainnet',
    11155111: 'sepolia',
    17000: 'holesky',
    10: 'optimism-mainnet',
    11155420: 'optimism-sepolia',
    137: 'polygon-mainnet',
    80002: 'polygon-amoy',
    8453: 'base-mainnet',
    84532: 'base-sepolia',
    42161: 'arbitrum-mainnet',
    421614: 'arbitrum-sepolia',
    59144: 'linea-mainnet',
    59141: 'linea-sepolia',
    81457: 'blast-mainnet',
    168587773: 'blast-sepolia',
    42220: 'celo-mainnet',
    44787: 'celo-sepolia',
    5000: 'mantle-mainnet',
    534352: 'scroll-mainnet',
    534351: 'scroll-sepolia',
    130: 'unichain-mainnet',
    1301: 'unichain-sepolia',
  };

  final SharedPreferences _prefs;

  SettingsService._(this._prefs);

  /// Creates a [SettingsService] backed by SharedPreferences.
  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService._(prefs);
  }

  String get rpcUrl {
    final infura = infuraRpcUrl;
    if (infura != null) return infura;
    return _prefs.getString(_keyRpcUrl) ?? '';
  }

  Future<void> setRpcUrl(String url) => _prefs.setString(_keyRpcUrl, url);

  int get selectedChainId => _prefs.getInt(_keyChainId) ?? 11155111;

  Future<void> setSelectedChainId(int chainId) =>
      _prefs.setInt(_keyChainId, chainId);

  String get infuraApiKey => _prefs.getString(_keyInfuraApiKey) ?? '';

  Future<void> setInfuraApiKey(String key) =>
      _prefs.setString(_keyInfuraApiKey, key);

    String? get lastActiveWalletMode => _prefs.getString(_keyLastActiveWalletMode);

    Future<bool> setLastActiveWalletMode(String mode) =>
      _prefs.setString(_keyLastActiveWalletMode, mode);

    Future<bool> clearLastActiveWalletMode() =>
      _prefs.remove(_keyLastActiveWalletMode);

  /// Whether the currently selected chain is supported by Infura.
  bool get isInfuraSupported => isChainSupported(selectedChainId);

  /// The Infura RPC URL for the current chain and API key.
  ///
  /// Returns null if the chain is not supported or if the key is empty.
  String? get infuraRpcUrl => getInfuraUrl(selectedChainId, infuraApiKey);

  /// Checks if a specific chain ID is supported by Infura.
  static bool isChainSupported(int chainId) =>
      _infuraSubdomains.containsKey(chainId);

  /// Generates an Infura RPC URL for a given chain ID and API key.
  static String? getInfuraUrl(int chainId, String apiKey) {
    final subdomain = _infuraSubdomains[chainId];
    if (subdomain == null || apiKey.isEmpty) return null;
    return 'https://$subdomain.infura.io/v3/$apiKey';
  }
}
