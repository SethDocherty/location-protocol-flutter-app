import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';

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

      // Serialize to JSON (manual since library doesn't provide toJson)
      final jsonMap = {
        'uid': signed.uid,
        'schemaUID': signed.schemaUID,
        'recipient': signed.recipient,
        'time': signed.time.toInt(),
        'expirationTime': signed.expirationTime.toInt(),
        'revocable': signed.revocable,
        'refUID': signed.refUID,
        'data':
            '0x${signed.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
        'salt': signed.salt,
        'version': signed.version,
        'signature': {
          'v': signed.signature.v,
          'r': signed.signature.r,
          's': signed.signature.s,
        },
        'signer': signed.signer,
      };
      final jsonText = jsonEncode(jsonMap);

      // Deserialize
      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
      final dataHex = parsed['data'] as String;
      final dataClean = dataHex.startsWith('0x')
          ? dataHex.substring(2)
          : dataHex;
      final data = Uint8List.fromList([
        for (var i = 0; i < dataClean.length; i += 2)
          int.parse(dataClean.substring(i, i + 2), radix: 16),
      ]);
      final sigMap = parsed['signature'] as Map<String, dynamic>;
      final restored = SignedOffchainAttestation(
        uid: parsed['uid'] as String,
        schemaUID: parsed['schemaUID'] as String,
        recipient: parsed['recipient'] as String,
        time: BigInt.from(parsed['time'] as int),
        expirationTime: BigInt.from(parsed['expirationTime'] as int),
        revocable: parsed['revocable'] as bool,
        refUID: parsed['refUID'] as String,
        data: data,
        salt: parsed['salt'] as String,
        version: parsed['version'] as int,
        signature: EIP712Signature(
          v: sigMap['v'] as int,
          r: sigMap['r'] as String,
          s: sigMap['s'] as String,
        ),
        signer: parsed['signer'] as String,
      );

      // Verify
      final result = service.verifyOffchain(restored);
      expect(result.isValid, isTrue);
    });
  });
}
