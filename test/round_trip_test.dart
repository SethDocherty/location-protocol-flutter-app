import 'dart:convert';

import 'package:test/test.dart';
import 'package:web3dart/web3dart.dart';

import 'package:location_protocol_flutter_app/src/builder/attestation_builder.dart';
import 'package:location_protocol_flutter_app/src/eas/eip712_signer.dart';
import 'package:location_protocol_flutter_app/src/models/location_attestation.dart';

/// Well-known Hardhat test account #0.
const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  late EthPrivateKey privateKey;

  setUp(() {
    privateKey = EthPrivateKey.fromHex(_testPrivateKey);
  });

  group('Round-trip: build → sign → serialize → deserialize → verify', () {
    test('basic round-trip with memo', () {
      // 1. Build
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 37.7749,
        longitude: -122.4194,
        memo: 'Round-trip test',
        eventTimestamp: 1700000000,
      );

      // 2. Sign
      final signed = EIP712Signer.signLocationAttestation(
        attestation: unsigned,
        privateKey: privateKey,
      );

      expect(signed.signer, _testAddress);
      expect(
          EIP712Signer.verifyLocationAttestation(attestation: signed), isTrue);

      // 3. Serialize to JSON
      final json = signed.toJsonString();
      expect(json, isNotEmpty);
      expect(json.contains('"uid"'), isTrue);
      expect(json.contains('"signature"'), isTrue);
      expect(json.contains('"signer"'), isTrue);

      // 4. Deserialize
      final map = jsonDecode(json) as Map<String, dynamic>;
      final deserialized = OffchainLocationAttestation.fromJson(map);

      expect(deserialized.signer, signed.signer);
      expect(deserialized.uid, signed.uid);
      expect(deserialized.signature, signed.signature);
      expect(deserialized.eventTimestamp, signed.eventTimestamp);
      expect(deserialized.location, signed.location);
      expect(deserialized.memo, signed.memo);

      // 5. Verify the deserialized attestation
      expect(
          EIP712Signer.verifyLocationAttestation(attestation: deserialized),
          isTrue);
    });

    test('round-trip without memo', () {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 51.5074,
        longitude: -0.1278,
        eventTimestamp: 1700000100,
      );
      final signed = EIP712Signer.signLocationAttestation(
        attestation: unsigned,
        privateKey: privateKey,
      );
      final json = signed.toJsonString();
      final deserialized =
          OffchainLocationAttestation.fromJson(jsonDecode(json));
      expect(
          EIP712Signer.verifyLocationAttestation(attestation: deserialized),
          isTrue);
    });

    test('round-trip with media fields', () {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 40.7128,
        longitude: -74.0060,
        memo: 'NYC photo',
        eventTimestamp: 1700000200,
        mediaType: ['image/png'],
        mediaData: ['ipfs://QmTest123'],
      );
      final signed = EIP712Signer.signLocationAttestation(
        attestation: unsigned,
        privateKey: privateKey,
      );
      final json = signed.toJsonString();
      final deserialized =
          OffchainLocationAttestation.fromJson(jsonDecode(json));

      expect(deserialized.mediaType, ['image/png']);
      expect(deserialized.mediaData, ['ipfs://QmTest123']);
      expect(
          EIP712Signer.verifyLocationAttestation(attestation: deserialized),
          isTrue);
    });

    test('pretty-printed JSON round-trip', () {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 48.8566,
        longitude: 2.3522,
        memo: 'Paris',
        eventTimestamp: 1700000300,
      );
      final signed = EIP712Signer.signLocationAttestation(
        attestation: unsigned,
        privateKey: privateKey,
      );
      final prettyJson = signed.toJsonString(pretty: true);
      final deserialized =
          OffchainLocationAttestation.fromJson(jsonDecode(prettyJson));
      expect(
          EIP712Signer.verifyLocationAttestation(attestation: deserialized),
          isTrue);
    });

    test('tampered location data fails verification', () {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 37.7749,
        longitude: -122.4194,
        memo: 'Tamper test',
        eventTimestamp: 1700000400,
      );
      final signed = EIP712Signer.signLocationAttestation(
        attestation: unsigned,
        privateKey: privateKey,
      );

      // Tamper with the location field after signing
      final map = jsonDecode(signed.toJsonString()) as Map<String, dynamic>;
      map['location'] =
          '{"type":"Point","coordinates":[0.0,0.0]}'; // different coords
      final tampered = OffchainLocationAttestation.fromJson(map);

      expect(
          EIP712Signer.verifyLocationAttestation(attestation: tampered),
          isFalse);
    });

    test('tampered memo fails verification', () {
      final unsigned = AttestationBuilder.fromCoordinates(
        latitude: 37.7749,
        longitude: -122.4194,
        memo: 'Original memo',
        eventTimestamp: 1700000500,
      );
      final signed = EIP712Signer.signLocationAttestation(
        attestation: unsigned,
        privateKey: privateKey,
      );

      final map = jsonDecode(signed.toJsonString()) as Map<String, dynamic>;
      map['memo'] = 'Tampered memo';
      final tampered = OffchainLocationAttestation.fromJson(map);

      expect(
          EIP712Signer.verifyLocationAttestation(attestation: tampered),
          isFalse);
    });

    test('two different locations produce different UIDs', () {
      final att1 = EIP712Signer.signLocationAttestation(
        attestation: AttestationBuilder.fromCoordinates(
          latitude: 37.7749,
          longitude: -122.4194,
          eventTimestamp: 1700000000,
        ),
        privateKey: privateKey,
      );
      final att2 = EIP712Signer.signLocationAttestation(
        attestation: AttestationBuilder.fromCoordinates(
          latitude: 51.5074,
          longitude: -0.1278,
          eventTimestamp: 1700000000,
        ),
        privateKey: privateKey,
      );
      expect(att1.uid, isNot(att2.uid));
    });
  });
}
