import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/utils/attestation_json.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

void main() {
  group('Verify JSON round-trip', () {
    test('sign → serialize → deserialize → verify', () async {
      final service = AttestationService(
        signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
        chainId: 11155111,
        rpcUrl: 'https://unused.rpc',
      );

      // Sign
      final signed = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'json round trip',
      );

      final jsonText = encodeSignedOffchainAttestationJson(signed);
      final restored = decodeSignedOffchainAttestationJson(jsonText);

      // Verify
      final result = service.verifyOffchain(restored);
      expect(result.isValid, isTrue);
    });
  });
}
