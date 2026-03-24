import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/screens/onchain_attest_screen.dart';
import 'package:location_protocol_flutter_app/settings/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

class TestAppWalletProvider extends AppWalletProvider {
  TestAppWalletProvider(SettingsService settingsService)
      : super(settingsService: settingsService);

  BuildContext? lastContext;
  Map<String, dynamic>? lastTxRequest;
  int callCount = 0;

  @override
  Future<String?> sendTransaction(
    Map<String, dynamic> txRequest, {
    BuildContext? context,
  }) async {
    callCount += 1;
    lastContext = context;
    lastTxRequest = txRequest;
    return '0xtx-hash';
  }
}

class FakeOnchainAttestationService extends AttestationService {
  FakeOnchainAttestationService()
      : super(
          signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
          chainId: 11155111,
          rpcUrl: 'https://unused.rpc',
        );

  @override
  Uint8List buildAttestCallData({
    required double lat,
    required double lng,
    required String memo,
    BigInt? eventTimestamp,
  }) {
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Map<String, dynamic> buildTxRequest({
    required Uint8List callData,
    required String contractAddress,
  }) {
    return const {
      'to': '0x0000000000000000000000000000000000000001',
      'data': '0x1234',
      'from': '0x0000000000000000000000000000000000000002',
      'chainId': '0xaa36a7',
    };
  }

  @override
  Future<String> waitForAttestationUid(
    String txHash, {
    int maxRetries = 15,
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    return '0xattestation-uid';
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('passes BuildContext when sending onchain transactions', (
    tester,
  ) async {
    final settingsService = await SettingsService.create();
    final walletProvider = TestAppWalletProvider(settingsService);
    await walletProvider.ready;

    final service = FakeOnchainAttestationService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppWalletProvider>.value(
        value: walletProvider,
        child: MaterialApp(
          home: OnchainAttestScreen(service: service),
        ),
      ),
    );

    await tester.tap(find.text('Submit Onchain Attestation'));
    await tester.pumpAndSettle();

    expect(walletProvider.callCount, 1);
    expect(walletProvider.lastContext, isNotNull);
    expect(find.text('TX Hash: 0xtx-hash'), findsOneWidget);
    expect(find.text('Attestation UID: 0xattestation-uid'), findsOneWidget);
  });
}