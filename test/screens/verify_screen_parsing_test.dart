import 'dart:convert';

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
      final expectedCanonical = signedOffchainAttestationToJsonMap(signed);
      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
      final sig = parsed['sig'] as Map<String, dynamic>;
      final types = sig['types'] as Map<String, dynamic>;
      final message = sig['message'] as Map<String, dynamic>;
      final signature = sig['signature'] as Map<String, dynamic>;

      expect(parsed, equals(expectedCanonical));
      expect(parsed.keys, unorderedEquals(const ['signer', 'sig']));

      expect(parsed['signer'], signed.signer);
      expect(sig['uid'], signed.uid);
      expect(sig['primaryType'], 'Attest');
      expect(sig.keys, unorderedEquals(const [
        'domain',
        'primaryType',
        'types',
        'message',
        'signature',
        'uid',
      ]));
      expect(sig['domain'], isA<Map<String, dynamic>>());
      expect(types.keys, unorderedEquals(const ['EIP712Domain', 'Attest']));
      expect(
        types['EIP712Domain'],
        equals(
          ((expectedCanonical['sig'] as Map<String, dynamic>)['types']
              as Map<String, dynamic>)['EIP712Domain'],
        ),
      );
      expect(types['Attest'], isA<List<dynamic>>());
      expect(signature, equals({
        'v': signed.signature.v,
        'r': signed.signature.r,
        's': signed.signature.s,
      }));
      expect(message['schema'], signed.schemaUID);
      expect(message['time'], isA<int>());
      expect(message['expirationTime'], isA<int>());
      expect(message['version'], isA<int>());

      final restored = decodeSignedOffchainAttestationJson(jsonText);

      final result = service.verifyOffchain(restored);
      expect(result.isValid, isTrue);
    });

    test('decode rejects non-canonical JSON', () {
      expect(
        () => decodeSignedOffchainAttestationJson(
          '{"uid":"0x1234","schemaUID":"0x5678"}',
        ),
        throwsFormatException,
      );
    });

    test('decode rejects canonical-looking JSON with string scalar fields', () async {
      final service = AttestationService(
        signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
        chainId: 11155111,
        rpcUrl: 'https://unused.rpc',
      );

      final signed = await service.signOffchain(
        lat: 40.7128,
        lng: -74.0060,
        memo: 'non-canonical scalar rejection',
      );

      final canonical = signedOffchainAttestationToJsonMap(signed);
      final mutated = Map<String, dynamic>.from(canonical);
      final sig = Map<String, dynamic>.from(mutated['sig'] as Map<String, dynamic>);
      final message = Map<String, dynamic>.from(sig['message'] as Map<String, dynamic>);

      message['version'] = '${message['version']}';
      message['time'] = '${message['time']}';
      message['expirationTime'] = '${message['expirationTime']}';

      sig['message'] = message;
      mutated['sig'] = sig;

      expect(
        () => decodeSignedOffchainAttestationJson(jsonEncode(mutated)),
        throwsFormatException,
      );
    });

    test('decode rejects canonical-looking JSON with extra types entries', () async {
      final service = AttestationService(
        signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
        chainId: 11155111,
        rpcUrl: 'https://unused.rpc',
      );

      final signed = await service.signOffchain(
        lat: 34.0522,
        lng: -118.2437,
        memo: 'non-canonical types rejection',
      );

      final canonical = signedOffchainAttestationToJsonMap(signed);
      final mutated = Map<String, dynamic>.from(canonical);
      final sig = Map<String, dynamic>.from(mutated['sig'] as Map<String, dynamic>);
      final types = Map<String, dynamic>.from(sig['types'] as Map<String, dynamic>);

      types['UnexpectedType'] = const <Map<String, String>>[
        {'name': 'unexpected', 'type': 'uint256'},
      ];

      sig['types'] = types;
      mutated['sig'] = sig;

      expect(
        () => decodeSignedOffchainAttestationJson(jsonEncode(mutated)),
        throwsFormatException,
      );
    });

    test('fromJsonMap accepts in-memory toJson map with BigInt message values', () async {
      final service = AttestationService(
        signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
        chainId: 11155111,
        rpcUrl: 'https://unused.rpc',
      );

      final signed = await service.signOffchain(
        lat: 51.5074,
        lng: -0.1278,
        memo: 'in-memory toJson round trip',
      );

      final restored = signedOffchainAttestationFromJsonMap(
        Map<String, dynamic>.from(signed.toJson()),
      );

      final result = service.verifyOffchain(restored);
      expect(result.isValid, isTrue);
      expect(restored.uid, signed.uid);
    });
  });
}
