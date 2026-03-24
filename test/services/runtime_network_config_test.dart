import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/services/runtime_network_config.dart';
import 'package:location_protocol_flutter_app/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: '');
  });

  test('copies resolved chain and rpc values from SettingsService', () async {
    final service = await SettingsService.create();
    await service.setSelectedChainId(10);
    await service.setRpcUrl('https://rpc.example.com');

    final config = RuntimeNetworkConfig.fromSettings(service);

    expect(config.selectedChainId, 10);
    expect(config.rpcUrl, 'https://rpc.example.com');
    expect(config.hasRpcUrl, isTrue);
  });

  test('snapshot does not change after settings mutate', () async {
    final service = await SettingsService.create();
    await service.setSelectedChainId(11155111);
    await service.setRpcUrl('https://initial.rpc');

    final config = RuntimeNetworkConfig.fromSettings(service);

    await service.setSelectedChainId(1);
    await service.setRpcUrl('https://updated.rpc');

    expect(config.selectedChainId, 11155111);
    expect(config.rpcUrl, 'https://initial.rpc');
    expect(config.hasRpcUrl, isTrue);
  });
}
