import '../settings/settings_service.dart';

/// Immutable snapshot of the app's resolved network settings.
class RuntimeNetworkConfig {
  final int selectedChainId;
  final String rpcUrl;

  const RuntimeNetworkConfig({
    required this.selectedChainId,
    required this.rpcUrl,
  });

  factory RuntimeNetworkConfig.fromSettings(SettingsService service) {
    return RuntimeNetworkConfig(
      selectedChainId: service.selectedChainId,
      rpcUrl: service.rpcUrl,
    );
  }

  bool get hasRpcUrl => rpcUrl.isNotEmpty;
}