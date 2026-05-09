import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/utils/attestation_json.dart';
import 'package:location_protocol_flutter_app/widgets/attestation_result_card.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('copy full result exports app JSON that can be decoded', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardText};
        }
        return null;
      },
    );

    final service = AttestationService(
      signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
      chainId: 11155111,
      rpcUrl: 'https://unused.rpc',
    );

    final attestation = await service.signOffchain(
      lat: 37.7749,
      lng: -122.4194,
      memo: 'copy me',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AttestationResultCard(attestation: attestation)),
      ),
    );

    await tester.tap(find.text('Copy Full Result'));
    await tester.pump();

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final restored = decodeSignedOffchainAttestationJson(clipboardData!.text!);

    expect(restored.uid, attestation.uid);
    expect(restored.signer, attestation.signer);
    expect(
      find.text('Attestation copied to clipboard as JSON'),
      findsOneWidget,
    );

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}
