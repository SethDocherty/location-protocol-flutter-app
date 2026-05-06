import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/providers/schema_provider.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/screens/sign_screen.dart';
import 'package:provider/provider.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

class FakeSignAttestationService extends AttestationService {
  Map<String, dynamic>? lastUserData;

  FakeSignAttestationService()
    : super(
        signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
        chainId: 11155111,
        rpcUrl: 'https://unused.rpc',
      );

  @override
  Future<SignedOffchainAttestation> signOffchainWithData({
    required SchemaDefinition schema,
    required double lat,
    required double lng,
    required Map<String, dynamic> userData,
  }) {
    lastUserData = userData;
    return super.signOffchainWithData(
      schema: schema,
      lat: lat,
      lng: lng,
      userData: userData,
    );
  }
}

void main() {
  testWidgets('parses bytes[] fields into byte arrays before signing', (
    tester,
  ) async {
    final service = FakeSignAttestationService();
    final schemaProvider = SchemaProvider(
      initialFields: [SchemaField(type: 'bytes[]', name: 'payload')],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SchemaProvider>.value(
        value: schemaProvider,
        child: MaterialApp(home: SignScreen(service: service)),
      ),
    );

    await tester.enterText(find.byType(TextField).at(2), '0x1234, 0xabcd');
    await tester.tap(find.text('Sign Attestation'));
    await tester.pumpAndSettle();

    final payload = service.lastUserData?['payload'];
    expect(payload, isA<List<Uint8List>>());
    expect((payload as List<Uint8List>)[0], orderedEquals([0x12, 0x34]));
    expect(payload[1], orderedEquals([0xab, 0xcd]));
  });
}
