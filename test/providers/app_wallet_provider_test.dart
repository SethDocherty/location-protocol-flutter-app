import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';

void main() {
  test('AppWalletProvider default state is none', () {
    final provider = AppWalletProvider();
    expect(provider.connectionType, ConnectionType.none);
    expect(provider.isConnected, false);
    expect(provider.canSendTransactions, false);
  });

  test('setPrivateKey switches connection to privateKey', () {
    final provider = AppWalletProvider();
    // Use a valid 32-byte (64 char) hex string for the private key
    const validKey = '0000000000000000000000000000000000000000000000000000000000000001';
    provider.setPrivateKey(validKey);
    expect(provider.connectionType, ConnectionType.privateKey);
    expect(provider.isConnected, true);
    expect(provider.walletAddress, isNotNull);
    expect(provider.canSendTransactions, false); // Private keys cannot send tx in this specific app logic
  });
}
