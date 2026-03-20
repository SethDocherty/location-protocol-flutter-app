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

    test('privateKeyHex defaults to empty string', () async {
      final service = await SettingsService.create();
      expect(service.privateKeyHex, '');
    });

    test('saves and retrieves privateKeyHex', () async {
      final service = await SettingsService.create();
      await service.setPrivateKeyHex('abcd1234');
      expect(service.privateKeyHex, 'abcd1234');
    });

    test('clearPrivateKey removes the stored key', () async {
      final service = await SettingsService.create();
      await service.setPrivateKeyHex('secret');
      await service.clearPrivateKey();
      expect(service.privateKeyHex, '');
    });
  });
}
