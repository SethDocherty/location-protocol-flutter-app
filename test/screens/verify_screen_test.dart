import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/screens/verify_screen.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

void main() {
  testWidgets('verify screen explains canonical EAS JSON input', (
    tester,
  ) async {
    final service = AttestationService(
      signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
      chainId: 11155111,
      rpcUrl: 'https://unused.rpc',
    );

    await tester.pumpWidget(MaterialApp(home: VerifyScreen(service: service)));

    expect(
      find.text('Paste canonical EAS offchain attestation JSON to verify it.'),
      findsOneWidget,
    );
    expect(find.textContaining('{"signer":"0x...","sig":'), findsOneWidget);
  });
}
