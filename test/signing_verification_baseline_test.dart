import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:blockchain_utils/blockchain_utils.dart';

import 'package:location_protocol_flutter_app/src/builder/attestation_builder.dart';
import 'package:location_protocol_flutter_app/src/eas/abi_encoder.dart';
import 'package:location_protocol_flutter_app/src/eas/eip712_signer.dart';
import 'package:location_protocol_flutter_app/src/eas/local_key_signer.dart';
import 'package:location_protocol_flutter_app/src/eas/schema_config.dart';
import 'package:location_protocol_flutter_app/src/models/location_attestation.dart';

import 'fixtures/signing_fixtures.dart';

void expectParity(
  OffchainLocationAttestation a,
  OffchainLocationAttestation b, {
  String description = '',
}) {
  final label = description.isNotEmpty ? ' ($description)' : '';
  expect(a.uid, b.uid, reason: 'UIDs differ$label');
  expect(a.signature, b.signature, reason: 'Signatures differ$label');
  expect(a.signer.toLowerCase(), b.signer.toLowerCase(),
      reason: 'Signers differ$label');
  expect(
    EIP712Signer.verifyLocationAttestation(attestation: a),
    isTrue,
    reason: 'First attestation fails verification$label',
  );
  expect(
    EIP712Signer.verifyLocationAttestation(attestation: b),
    isTrue,
    reason: 'Second attestation fails verification$label',
  );
}

UnsignedLocationAttestation buildFixtureAttestation() {
  return AttestationBuilder.fromCoordinates(
    latitude: 37.7749,
    longitude: -122.4194,
    memo: kFixtureMemo,
    eventTimestamp: kFixtureEventTimestamp,
  );
}

void main() {
  group('Golden snapshots — canonical intermediate outputs', () {
    test('encoded data hash matches fixture', () {
      final attestation = buildFixtureAttestation();
      final encoded = AbiEncoder.encodeAttestationData(attestation);
      final hash =
          '0x${Uint8List.fromList(QuickCrypto.keccack256Hash(encoded)).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      expect(hash, kFixtureEncodedDataHash,
          reason: 'ABI-encoded attestation data hash must be deterministic');
    });

    test('domain separator matches fixture', () {
      final ds = EIP712Signer.computeDomainSeparator(
        chainId: SchemaConfig.sepoliaChainId,
        contractAddress: SchemaConfig.sepoliaContractAddress,
      );
      final hex =
          '0x${ds.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      expect(hex, kFixtureDomainSeparator,
          reason: 'Domain separator must be deterministic for Sepolia EAS');
    });

    test('struct hash matches fixture', () {
      final attestation = buildFixtureAttestation();
      final encoded = AbiEncoder.encodeAttestationData(attestation);
      final encodedDataHash =
          Uint8List.fromList(QuickCrypto.keccack256Hash(encoded));
      final sh = EIP712Signer.computeStructHash(
        schemaUid: _hexToBytes32(SchemaConfig.sepoliaSchemaUid),
        recipient: '0x0000000000000000000000000000000000000000',
        time: kFixtureEventTimestamp,
        expirationTime: 0,
        revocable: true,
        encodedDataHash: encodedDataHash,
      );
      final hex =
          '0x${sh.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      expect(hex, kFixtureStructHash,
          reason: 'Struct hash must be deterministic for the canonical attestation');
    });

    test('EIP-712 digest matches fixture', () {
      final attestation = buildFixtureAttestation();
      final encoded = AbiEncoder.encodeAttestationData(attestation);
      final encodedDataHash =
          Uint8List.fromList(QuickCrypto.keccack256Hash(encoded));
      final ds = EIP712Signer.computeDomainSeparator(
        chainId: SchemaConfig.sepoliaChainId,
        contractAddress: SchemaConfig.sepoliaContractAddress,
      );
      final sh = EIP712Signer.computeStructHash(
        schemaUid: _hexToBytes32(SchemaConfig.sepoliaSchemaUid),
        recipient: '0x0000000000000000000000000000000000000000',
        time: kFixtureEventTimestamp,
        expirationTime: 0,
        revocable: true,
        encodedDataHash: encodedDataHash,
      );
      final digest = EIP712Signer.computeDigest(
        domainSeparator: ds,
        structHash: sh,
      );
      final hex =
          '0x${digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      expect(hex, kFixtureDigest,
          reason: 'EIP-712 digest must be deterministic');
    });
  });

  group('Signed envelope shape', () {
    late OffchainLocationAttestation signed;

    setUp(() {
      signed = EIP712Signer.signLocationAttestation(
        attestation: buildFixtureAttestation(),
        privateKeyHex: kFixturePrivateKey,
      );
    });

    test('UID matches fixture', () {
      expect(signed.uid, kFixtureUid);
    });

    test('signer address matches fixture', () {
      expect(signed.signer, kFixtureSignerAddress);
    });

    test('signature v matches fixture', () {
      expect(signed.parsedSignature['v'], kFixtureSigV);
    });

    test('signature r matches fixture', () {
      expect(signed.parsedSignature['r'], kFixtureSigR);
    });

    test('signature s matches fixture', () {
      expect(signed.parsedSignature['s'], kFixtureSigS);
    });

    test('signature JSON matches fixture', () {
      final parsed = signed.parsedSignature;
      final canonical = jsonEncode({
        'v': parsed['v'],
        'r': parsed['r'],
        's': parsed['s'],
      });
      expect(canonical, kFixtureSignatureJson);
    });

    test('version field matches fixture', () {
      expect(signed.version, kFixtureAttestationVersion);
    });
  });

  group('Verification — positive case', () {
    test('valid signed record verifies correctly', () {
      final attestation = OffchainLocationAttestation(
        eventTimestamp: kFixtureEventTimestamp,
        srs: kFixtureSrs,
        locationType: kFixtureLocationType,
        location: kFixtureLocation,
        recipeType: const [],
        recipePayload: const [],
        mediaType: const [],
        mediaData: const [],
        memo: kFixtureMemo,
        expirationTime: 0,
        revocable: true,
        uid: kFixtureUid,
        signature: kFixtureSignatureJson,
        signer: kFixtureSignerAddress,
        version: kFixtureAttestationVersion,
      );

      expect(
        EIP712Signer.verifyLocationAttestation(attestation: attestation),
        isTrue,
        reason: 'Hard-coded valid fixture must pass verification',
      );
      expect(
        EIP712Signer.recoverSigner(attestation: attestation)?.toLowerCase(),
        kFixtureSignerAddress.toLowerCase(),
        reason: 'Recovered signer must match fixture signer',
      );
    });
  });

  group('Verification — negative cases', () {
    OffchainLocationAttestation _withOverrides({
      String? location,
      String? signer,
      String? signature,
      String? memo,
    }) {
      return OffchainLocationAttestation(
        eventTimestamp: kFixtureEventTimestamp,
        srs: kFixtureSrs,
        locationType: kFixtureLocationType,
        location: location ?? kFixtureLocation,
        recipeType: const [],
        recipePayload: const [],
        mediaType: const [],
        mediaData: const [],
        memo: memo ?? kFixtureMemo,
        expirationTime: 0,
        revocable: true,
        uid: kFixtureUid,
        signature: signature ?? kFixtureSignatureJson,
        signer: signer ?? kFixtureSignerAddress,
        version: kFixtureAttestationVersion,
      );
    }

    test('tampered payload — different location fails verification', () {
      final tampered = _withOverrides(
        location: '{"type":"Point","coordinates":[0.0,0.0]}',
      );
      expect(
        EIP712Signer.verifyLocationAttestation(attestation: tampered),
        isFalse,
      );
    });

    test('wrong signer — replaced signer address fails verification', () {
      const wrongSigner = '0x0000000000000000000000000000000000000001';
      final tampered = _withOverrides(signer: wrongSigner);
      expect(
        EIP712Signer.verifyLocationAttestation(attestation: tampered),
        isFalse,
      );
    });

    test('malformed signature — corrupted bytes fail verification', () {
      final badSig = jsonEncode({
        'v': kFixtureSigV,
        'r': '0x${'00' * 32}',
        's': kFixtureSigS,
      });
      final tampered = _withOverrides(signature: badSig);
      expect(
        EIP712Signer.verifyLocationAttestation(attestation: tampered),
        isFalse,
      );
    });
  });

  group('Parity — sync vs async implementation', () {
    test('both implementations produce identical UID and signature', () async {
      final attestation = buildFixtureAttestation();
      final signer = LocalKeySigner(kFixturePrivateKey);

      final syncSigned = EIP712Signer.signLocationAttestation(
        attestation: attestation,
        privateKeyHex: kFixturePrivateKey,
      );

      final asyncSigned = await EIP712Signer.signLocationAttestationWith(
        attestation: attestation,
        signer: signer,
      );

      expectParity(syncSigned, asyncSigned,
          description: 'sync vs async with LocalKeySigner');
    });

    test('sync output matches fixture golden values', () {
      final signed = EIP712Signer.signLocationAttestation(
        attestation: buildFixtureAttestation(),
        privateKeyHex: kFixturePrivateKey,
      );
      expect(signed.uid, kFixtureUid,
          reason: 'Sync path UID must match golden fixture');
      expect(signed.parsedSignature['r'], kFixtureSigR,
          reason: 'Sync path sig.r must match golden fixture');
    });

    test('async output matches fixture golden values', () async {
      final signer = LocalKeySigner(kFixturePrivateKey);
      final signed = await EIP712Signer.signLocationAttestationWith(
        attestation: buildFixtureAttestation(),
        signer: signer,
      );
      expect(signed.uid, kFixtureUid,
          reason: 'Async path UID must match golden fixture');
      expect(signed.parsedSignature['r'], kFixtureSigR,
          reason: 'Async path sig.r must match golden fixture');
    });
  });
}

Uint8List _hexToBytes32(String hex) {
  final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
  final bytes = Uint8List(32);
  for (int i = 0; i < 32 && i * 2 + 1 < clean.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
