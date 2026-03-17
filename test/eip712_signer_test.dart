import 'package:flutter_test/flutter_test.dart';

import 'package:location_protocol_flutter_app/src/builder/attestation_builder.dart';
import 'package:location_protocol_flutter_app/src/eas/eip712_signer.dart';
import 'package:location_protocol_flutter_app/src/eas/local_key_signer.dart';
import 'package:location_protocol_flutter_app/src/eas/schema_config.dart';
import 'package:location_protocol_flutter_app/src/models/location_attestation.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  group('EIP712Signer.computeDomainSeparator', () {
    test('is deterministic', () {
      final d1 = EIP712Signer.computeDomainSeparator(
        chainId: SchemaConfig.sepoliaChainId,
        contractAddress: SchemaConfig.sepoliaContractAddress,
      );
      final d2 = EIP712Signer.computeDomainSeparator(
        chainId: SchemaConfig.sepoliaChainId,
        contractAddress: SchemaConfig.sepoliaContractAddress,
      );
      expect(d1, equals(d2));
    });

    test('returns 32 bytes', () {
      final ds = EIP712Signer.computeDomainSeparator(
        chainId: SchemaConfig.sepoliaChainId,
        contractAddress: SchemaConfig.sepoliaContractAddress,
      );
      expect(ds.length, 32);
    });

    test('changes with different chainId', () {
      final ds1 = EIP712Signer.computeDomainSeparator(
        chainId: 1,
        contractAddress: SchemaConfig.sepoliaContractAddress,
      );
      final ds2 = EIP712Signer.computeDomainSeparator(
        chainId: SchemaConfig.sepoliaChainId,
        contractAddress: SchemaConfig.sepoliaContractAddress,
      );
      expect(ds1, isNot(equals(ds2)));
    });
  });

  group('EIP712Signer.signLocationAttestation', () {
    UnsignedLocationAttestation buildTestAttestation() {
      return AttestationBuilder.fromCoordinates(
        latitude: 37.7749,
        longitude: -122.4194,
        memo: 'Test attestation',
        eventTimestamp: 1700000000,
      );
    }

    test('returns OffchainLocationAttestation with correct signer', () {
      final att = buildTestAttestation();
      final signed = EIP712Signer.signLocationAttestation(
        attestation: att,
        privateKeyHex: _testPrivateKey,
      );
      expect(signed.signer, _testAddress);
    });

    test('UID is a 0x-prefixed 32-byte hex string', () {
      final att = buildTestAttestation();
      final signed = EIP712Signer.signLocationAttestation(
        attestation: att,
        privateKeyHex: _testPrivateKey,
      );
      expect(signed.uid, startsWith('0x'));
      expect(signed.uid.length, 66);
    });

    test('signature JSON contains v, r, s', () {
      final att = buildTestAttestation();
      final signed = EIP712Signer.signLocationAttestation(
        attestation: att,
        privateKeyHex: _testPrivateKey,
      );
      final sig = signed.parsedSignature;
      expect(sig.containsKey('v'), isTrue);
      expect(sig.containsKey('r'), isTrue);
      expect(sig.containsKey('s'), isTrue);
      expect(sig['v'], anyOf(27, 28));
    });

    test('r and s are 32-byte hex strings (0x-prefixed, 66 chars)', () {
      final att = buildTestAttestation();
      final signed = EIP712Signer.signLocationAttestation(
        attestation: att,
        privateKeyHex: _testPrivateKey,
      );
      final sig = signed.parsedSignature;
      final r = sig['r'].toString();
      final s = sig['s'].toString();
      expect(r, startsWith('0x'));
      expect(r.length, 66);
      expect(s, startsWith('0x'));
      expect(s.length, 66);
    });

    test('signing same data with same key is deterministic', () {
      final att = buildTestAttestation();
      final s1 = EIP712Signer.signLocationAttestation(
        attestation: att,
        privateKeyHex: _testPrivateKey,
      );
      final s2 = EIP712Signer.signLocationAttestation(
        attestation: att,
        privateKeyHex: _testPrivateKey,
      );
      expect(s1.uid, s2.uid);
      expect(s1.signature, s2.signature);
    });

    test('version field is set correctly', () {
      final att = buildTestAttestation();
      final signed = EIP712Signer.signLocationAttestation(
        attestation: att,
        privateKeyHex: _testPrivateKey,
      );
      expect(signed.version, SchemaConfig.attestationVersion);
    });
  });

  group('EIP712Signer.verifyLocationAttestation', () {
    test('verifies a freshly signed attestation', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 37.7749,
        longitude: -122.4194,
        memo: 'Verify me',
        eventTimestamp: 1700000000,
      );
      final signed = EIP712Signer.signLocationAttestation(
        attestation: att,
        privateKeyHex: _testPrivateKey,
      );
      expect(EIP712Signer.verifyLocationAttestation(attestation: signed),
          isTrue);
    });

    test('fails when signer field is tampered', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 51.5074,
        longitude: -0.1278,
        memo: 'London',
        eventTimestamp: 1700000001,
      );
      final signed = EIP712Signer.signLocationAttestation(
        attestation: att,
        privateKeyHex: _testPrivateKey,
      );

      final tampered = OffchainLocationAttestation(
        eventTimestamp: signed.eventTimestamp,
        srs: signed.srs,
        locationType: signed.locationType,
        location: signed.location,
        recipeType: signed.recipeType,
        recipePayload: signed.recipePayload,
        mediaType: signed.mediaType,
        mediaData: signed.mediaData,
        memo: signed.memo,
        recipient: signed.recipient,
        expirationTime: signed.expirationTime,
        revocable: signed.revocable,
        uid: signed.uid,
        signature: signed.signature,
        signer: '0x0000000000000000000000000000000000000001',
        version: signed.version,
      );

      expect(
          EIP712Signer.verifyLocationAttestation(attestation: tampered),
          isFalse);
    });

    test('recoverSigner returns the test address', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 40.7128,
        longitude: -74.0060,
        memo: 'New York',
        eventTimestamp: 1700000002,
      );
      final signed = EIP712Signer.signLocationAttestation(
        attestation: att,
        privateKeyHex: _testPrivateKey,
      );
      final recovered = EIP712Signer.recoverSigner(attestation: signed);
      expect(recovered?.toLowerCase(), _testAddress.toLowerCase());
    });
  });

  group('EIP712Signer.signLocationAttestationWith (async)', () {
    UnsignedLocationAttestation buildTestAttestation() {
      return AttestationBuilder.fromCoordinates(
        latitude: 37.7749,
        longitude: -122.4194,
        memo: 'Async test',
        eventTimestamp: 1700000000,
      );
    }

    test('produces same result as sync method', () async {
      final att = buildTestAttestation();
      final signer = LocalKeySigner(_testPrivateKey);

      final asyncSigned = await EIP712Signer.signLocationAttestationWith(
        attestation: att,
        signer: signer,
      );
      final syncSigned = EIP712Signer.signLocationAttestation(
        attestation: att,
        privateKeyHex: _testPrivateKey,
      );

      expect(asyncSigned.uid, syncSigned.uid);
      expect(asyncSigned.signature, syncSigned.signature);
      expect(asyncSigned.signer, syncSigned.signer);
    });

    test('produced attestation verifies correctly', () async {
      final att = buildTestAttestation();
      final signer = LocalKeySigner(_testPrivateKey);

      final signed = await EIP712Signer.signLocationAttestationWith(
        attestation: att,
        signer: signer,
      );

      expect(
        EIP712Signer.verifyLocationAttestation(attestation: signed),
        isTrue,
      );
    });

    test('signer address is set correctly', () async {
      final att = buildTestAttestation();
      final signer = LocalKeySigner(_testPrivateKey);

      final signed = await EIP712Signer.signLocationAttestationWith(
        attestation: att,
        signer: signer,
      );

      expect(signed.signer, _testAddress);
    });
  });
}
