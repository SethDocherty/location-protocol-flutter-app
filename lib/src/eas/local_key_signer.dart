import 'dart:typed_data';

import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

import 'attestation_signer.dart';

/// Signs digests using a raw [EthPrivateKey] held in memory.
///
/// This is the equivalent of the previous direct `sign(digest, key)` call,
/// wrapped behind the [AttestationSigner] interface. Used by existing tests
/// and for offline/local signing.
class LocalKeySigner implements AttestationSigner {
  final EthPrivateKey _privateKey;

  LocalKeySigner(this._privateKey);

  @override
  String get address => _privateKey.address.hexEip55;

  @override
  Future<MsgSignature> signDigest(Uint8List digest) async {
    final raw = sign(digest, _privateKey.privateKey);
    final v = raw.v < 27 ? raw.v + 27 : raw.v;
    return MsgSignature(raw.r, raw.s, v);
  }

  /// Delegates to [signDigest] using the pre-computed EIP-712 digest.
  ///
  /// [LocalKeySigner] calls `sign()` directly on the raw bytes with no
  /// extra prefix, so the pre-computed digest is exactly what we need.
  @override
  Future<MsgSignature> signTypedData({
    required Map<String, dynamic> domain,
    required Map<String, dynamic> types,
    required Map<String, dynamic> message,
    required Uint8List precomputedDigest,
  }) =>
      signDigest(precomputedDigest);
}
