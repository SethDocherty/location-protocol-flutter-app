import 'dart:typed_data';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:on_chain/on_chain.dart';

import 'attestation_signer.dart';
import 'ecdsa_signature.dart';

/// Signs digests using a raw Ethereum private key held in memory.
///
/// This is the equivalent of the previous direct `sign(digest, key)` call,
/// wrapped behind the [AttestationSigner] interface. Used by existing tests
/// and for offline/local signing.
class LocalKeySigner implements AttestationSigner {
  final ETHPrivateKey _privateKey;

  LocalKeySigner(String privateKeyHex)
      : _privateKey = ETHPrivateKey(privateKeyHex);

  @override
  String get address => _privateKey.publicKey().toAddress().address;

  @override
  Future<EcdsaSignature> signDigest(Uint8List digest) async {
    final raw = _privateKey.sign(digest, hashMessage: false);
    final r = BigInt.parse(BytesUtils.toHexString(raw.rBytes), radix: 16);
    final s = BigInt.parse(BytesUtils.toHexString(raw.sBytes), radix: 16);
    final v = raw.v < 27 ? raw.v + 27 : raw.v;
    return EcdsaSignature(r, s, v);
  }

  /// Delegates to [signDigest] using the pre-computed EIP-712 digest.
  ///
  /// [LocalKeySigner] calls `sign()` directly on the raw bytes with no
  /// extra prefix, so the pre-computed digest is exactly what we need.
  @override
  Future<EcdsaSignature> signTypedData({
    required Map<String, dynamic> domain,
    required Map<String, dynamic> types,
    required Map<String, dynamic> message,
    required Uint8List precomputedDigest,
  }) =>
      signDigest(precomputedDigest);
}
