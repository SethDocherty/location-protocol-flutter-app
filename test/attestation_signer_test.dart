import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:blockchain_utils/blockchain_utils.dart';
// ignore: depend_on_referenced_packages
import 'package:on_chain/on_chain.dart';

import 'package:location_protocol_flutter_app/src/eas/attestation_signer.dart';
import 'package:location_protocol_flutter_app/src/eas/local_key_signer.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  group('LocalKeySigner', () {
    late LocalKeySigner signer;

    setUp(() {
      signer = LocalKeySigner(_testPrivateKey);
    });

    test('implements AttestationSigner', () {
      expect(signer, isA<AttestationSigner>());
    });

    test('returns correct address', () {
      expect(signer.address, _testAddress);
    });

    test('signDigest produces valid signature', () async {
      final digest = Uint8List.fromList(
          QuickCrypto.keccack256Hash([1, 2, 3]));
      final sig = await signer.signDigest(digest);

      expect(sig.v, anyOf(27, 28));
      expect(sig.r, isNot(BigInt.zero));
      expect(sig.s, isNot(BigInt.zero));
    });

    test('signature can be verified via ecRecover', () async {
      final digest = Uint8List.fromList(
          QuickCrypto.keccack256Hash([7, 8, 9]));
      final sig = await signer.signDigest(digest);

      final rBytes = _bigIntToBytes32(sig.r);
      final sBytes = _bigIntToBytes32(sig.s);
      final vByte = sig.v - 27;
      final sigBytes = Uint8List.fromList([...rBytes, ...sBytes, vByte]);

      final recovered = ETHPublicKey.recoverPublicKey(digest, sigBytes,
              hashMessage: false)
          ?.toAddress()
          .address;
      expect(recovered?.toLowerCase(), _testAddress.toLowerCase());
    });
  });
}

Uint8List _bigIntToBytes32(BigInt value) {
  final hex = value.toRadixString(16).padLeft(64, '0');
  final bytes = Uint8List(32);
  for (int i = 0; i < 32; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
