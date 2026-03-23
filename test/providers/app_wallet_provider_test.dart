import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:location_protocol_flutter_app/services/reown_service.dart';

class MockReownService extends Mock implements ReownService {}

void main() {
  test('AppWalletProvider default state is none', () {
    final provider = AppWalletProvider();
    expect(provider.connectionType, ConnectionType.none);
    expect(provider.isConnected, false);
    expect(provider.canSendTransactions, false);
  });

  test('setPrivateKey switches connection to privateKey', () {
    final provider = AppWalletProvider();
    const validKey = '0000000000000000000000000000000000000000000000000000000000000001';
    provider.setPrivateKey(validKey);
    expect(provider.connectionType, ConnectionType.privateKey);
    expect(provider.isConnected, true);
    expect(provider.walletAddress, isNotNull);
    expect(provider.canSendTransactions, false);
  });

  test('setExternalAddress switches connection to external', () {
    final mockReown = MockReownService();
    final provider = AppWalletProvider(reownService: mockReown);
    const validAddress = '0x1234567890123456789012345678901234567890';
    provider.setExternalAddress(validAddress);
    expect(provider.connectionType, ConnectionType.external);
    expect(provider.isConnected, true);
    expect(provider.walletAddress, validAddress);
    expect(provider.canSendTransactions, true);
  });
}
