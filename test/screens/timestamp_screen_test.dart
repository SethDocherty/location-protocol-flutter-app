import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/screens/timestamp_screen.dart';
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

  @override
  Future<String?> sendTransaction(
    Map<String, dynamic> txRequest, {
    BuildContext? context,
  }) async {
    lastContext = context;
    lastTxRequest = txRequest;
    if (context == null) {
      throw StateError('Missing BuildContext');
    }
    return '0xtx-hash';
  }
}

class FakeTimestampService extends AttestationService {
  FakeTimestampService()
      : super(
          signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
          chainId: 11155111,
          rpcUrl: 'https://unused.rpc',
        );

  @override
  Future<bool> isTimestamped(String uid) async => false;

  @override
  Uint8List buildTimestampCallData(String uid) {
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Map<String, dynamic> buildTxRequest({
    required Uint8List callData,
    required String contractAddress,
  }) {
    return {
      'to': contractAddress,
      'data': '0x1234',
      'from': '0x0000000000000000000000000000000000000002',
      'chainId': '0xaa36a7',
    };
  }
}

Future<TestAppWalletProvider> _buildWalletProvider() async {
  final provider = TestAppWalletProvider(await SettingsService.create());
  await provider.ready;
  await provider.setExternalAddress(
    '0x1234567890123456789012345678901234567890',
  );
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('passes BuildContext when timestamping with an external wallet', (
    tester,
  ) async {
    final walletProvider = await _buildWalletProvider();
    final service = FakeTimestampService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppWalletProvider>.value(
        value: walletProvider,
        child: MaterialApp(
          home: TimestampScreen(service: service),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      '0x${'ab' * 32}',
    );
    await tester.tap(find.text('Timestamp Onchain'));
    await tester.pumpAndSettle();

    expect(walletProvider.lastContext, isNotNull);
    expect(find.textContaining('TX Hash: 0xtx-hash'), findsOneWidget);
    expect(find.textContaining('Bad state'), findsNothing);
  });
}
