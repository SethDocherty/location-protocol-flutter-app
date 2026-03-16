import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import 'package:location_protocol_flutter_app/src/eas/attestation_signer.dart';
import 'package:location_protocol_flutter_app/src/eas/local_key_signer.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

void main() {
  group('LocalKeySigner', () {
    late EthPrivateKey privateKey;
    late LocalKeySigner signer;

    setUp(() {
      privateKey = EthPrivateKey.fromHex(_testPrivateKey);
      signer = LocalKeySigner(privateKey);
    });

    test('implements AttestationSigner', () {
      expect(signer, isA<AttestationSigner>());
    });

    test('returns correct address', () {
      expect(signer.address, _testAddress);
    });

    test('signDigest produces valid signature', () async {
      final digest = keccak256(Uint8List.fromList([1, 2, 3]));
      final sig = await signer.signDigest(digest);

      expect(sig.v, anyOf(27, 28));
      expect(sig.r, isNot(BigInt.zero));
      expect(sig.s, isNot(BigInt.zero));
    });

    test('signDigest matches direct web3dart sign()', () async {
      final digest = keccak256(Uint8List.fromList([4, 5, 6]));
      final sigFromSigner = await signer.signDigest(digest);
      final sigDirect = sign(digest, privateKey.privateKey);

      expect(sigFromSigner.r, sigDirect.r);
      expect(sigFromSigner.s, sigDirect.s);
      final vDirect = sigDirect.v < 27 ? sigDirect.v + 27 : sigDirect.v;
      final vFromSigner =
          sigFromSigner.v < 27 ? sigFromSigner.v + 27 : sigFromSigner.v;
      expect(vFromSigner, vDirect);
    });

    test('signature can be verified via ecRecover', () async {
      final digest = keccak256(Uint8List.fromList([7, 8, 9]));
      final sig = await signer.signDigest(digest);

      final publicKey = ecRecover(digest, sig);
      final recovered = EthereumAddress.fromPublicKey(publicKey).hexEip55;
      expect(recovered, _testAddress);
    });
  });
}
