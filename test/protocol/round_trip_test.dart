import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  late AttestationService service;

  setUp(() {
    service = AttestationService(
      signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
      chainId: 11155111,
      rpcUrl: 'https://unused.rpc',
    );
  });

  group('Round trip — sign → verify', () {
    test('basic round trip succeeds', () async {
      final signed = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'round trip test',
      );

      final result = service.verifyOffchain(signed);

      expect(result.isValid, isTrue);
      expect(result.recoveredAddress.toLowerCase(), _testAddress.toLowerCase());
    });

    test('different coordinates produce different UIDs', () async {
      final a = await service.signOffchain(lat: 0, lng: 0, memo: 'a');
      final b = await service.signOffchain(lat: 90, lng: 180, memo: 'a');

      expect(a.uid, isNot(b.uid));
    });

    test('different memos produce different UIDs', () async {
      final a = await service.signOffchain(lat: 0, lng: 0, memo: 'hello');
      final b = await service.signOffchain(lat: 0, lng: 0, memo: 'world');

      expect(a.uid, isNot(b.uid));
    });

    test('attestation uses version 2 with salt', () async {
      final signed = await service.signOffchain(
        lat: 0,
        lng: 0,
        memo: 'version test',
      );

      expect(signed.version, 2);
      expect(signed.salt, isNotEmpty);
    });

    test('attestation uses app schema UID', () async {
      final signed = await service.signOffchain(
        lat: 0,
        lng: 0,
        memo: 'schema test',
      );

      expect(signed.schemaUID, AppSchema.schemaUID);
    });

    test('signer address matches key', () async {
      final signed = await service.signOffchain(
        lat: 0,
        lng: 0,
        memo: 'signer test',
      );

      expect(signed.signer.toLowerCase(), _testAddress.toLowerCase());
    });
  });
}
