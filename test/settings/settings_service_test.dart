import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location_protocol_flutter_app/settings/settings_service.dart';

void main() {
  group('SettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('rpcUrl defaults to empty string', () async {
      final service = await SettingsService.create();
      expect(service.rpcUrl, '');
    });

    test('saves and retrieves rpcUrl', () async {
      final service = await SettingsService.create();
      await service.setRpcUrl('https://rpc.example.com');
      expect(service.rpcUrl, 'https://rpc.example.com');
    });

    test('selectedChainId defaults to 11155111 (Sepolia)', () async {
      final service = await SettingsService.create();
      expect(service.selectedChainId, 11155111);
    });

    test('saves and retrieves selectedChainId', () async {
      final service = await SettingsService.create();
      await service.setSelectedChainId(1);
      expect(service.selectedChainId, 1);
    });



    test('generates correct Infura URL for Sepolia', () async {
      final service = await SettingsService.create();
      await service.setSelectedChainId(11155111);
      await service.setInfuraApiKey('test-key');
      expect(service.infuraRpcUrl, 'https://sepolia.infura.io/v3/test-key');
    });

    test('generates correct Infura URL for Optimism', () async {
      final service = await SettingsService.create();
      await service.setSelectedChainId(10);
      await service.setInfuraApiKey('test-key');
      expect(service.infuraRpcUrl, 'https://optimism-mainnet.infura.io/v3/test-key');
    });

    test('isInfuraSupported returns false for unsupported chains', () async {
      final service = await SettingsService.create();
      await service.setSelectedChainId(40); // Telos
      expect(service.isInfuraSupported, isFalse);
    });

    test('rpcUrl prioritizes Infura over manual setting', () async {
      final service = await SettingsService.create();
      await service.setRpcUrl('https://manual.rpc');
      await service.setInfuraApiKey('test-key');
      await service.setSelectedChainId(11155111); // Sepolia
      
      expect(service.rpcUrl, 'https://sepolia.infura.io/v3/test-key');
      
      await service.setSelectedChainId(10); // Optimism
      expect(service.rpcUrl, 'https://optimism-mainnet.infura.io/v3/test-key');
    });
  });
}
