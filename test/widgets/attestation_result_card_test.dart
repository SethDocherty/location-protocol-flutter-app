import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/widgets/attestation_result_card.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('copy EAS JSON exports the canonical EAS attestation envelope', (
    tester,
  ) async {
    String? clipboardText;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
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
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

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

    expect(find.text('Schema UID'), findsOneWidget);
    expect(find.text('Offchain Version'), findsOneWidget);
    expect(find.text('Copy EAS JSON'), findsOneWidget);

    await tester.tap(find.text('Copy EAS JSON'));
    await tester.pump();

    expect(clipboardText, isNotNull);

    final parsed = jsonDecode(clipboardText!) as Map<String, dynamic>;
    final sig = parsed['sig'] as Map<String, dynamic>;
    final message = sig['message'] as Map<String, dynamic>;
    final signature = sig['signature'] as Map<String, dynamic>;

    expect(parsed.keys.toSet(), equals({'signer', 'sig'}));
    expect(parsed['signer'], attestation.signer);
    expect(
      sig.keys.toSet(),
      equals({
        'domain',
        'primaryType',
        'types',
        'message',
        'signature',
        'uid',
      }),
    );
    expect(sig['domain'], isA<Map<String, dynamic>>());
    expect(sig['primaryType'], 'Attest');
    expect(sig['types'], isA<Map<String, dynamic>>());
    expect(sig['message'], isA<Map<String, dynamic>>());
    expect(sig['signature'], isA<Map<String, dynamic>>());
    expect(sig['uid'], attestation.uid);
    expect(message['schema'], attestation.schemaUID);
    expect(
      signature,
      equals({
        'v': attestation.signature.v,
        'r': attestation.signature.r,
        's': attestation.signature.s,
      }),
    );
    expect(
      find.text('Attestation copied to clipboard as EAS JSON'),
      findsOneWidget,
    );
  });
}
