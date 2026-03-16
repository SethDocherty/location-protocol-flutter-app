import 'dart:typed_data';

import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

/// Abstract interface for signing EIP-712 digests.
///
/// Decouples [EIP712Signer] from any specific wallet backend.
/// Implementations:
/// - [LocalKeySigner] — wraps a raw [EthPrivateKey] (tests, offline)
/// - `PrivyWalletSigner` — signs via Privy's embedded wallet RPC
abstract class AttestationSigner {
  /// The EIP-55 checksummed Ethereum address of this signer.
  String get address;

  /// Sign a 32-byte Keccak256 digest and return the (v, r, s) signature.
  ///
  /// Implementations may be async (e.g., Privy RPC call) or synchronous
  /// (e.g., local key). The [v] value MUST be in the [27, 28] range.
  Future<MsgSignature> signDigest(Uint8List digest);

  /// Signs using the full EIP-712 typed-data structure.
  ///
  /// The default implementation uses [precomputedDigest] (the EIP-712 hash
  /// already computed by [EIP712Signer]) and delegates to [signDigest].
  /// This is correct for [LocalKeySigner] which calls `sign()` on the raw
  /// bytes with no extra prefix.
  ///
  /// Wallet backends that support `eth_signTypedData_v4` (e.g. Privy) MUST
  /// override this method so the wallet—not this code—computes the final
  /// hash.  Using `personal_sign` with a pre-computed digest double-wraps
  /// the message and produces a signature that cannot be verified against
  /// the plain EIP-712 digest.
  Future<MsgSignature> signTypedData({
    required Map<String, dynamic> domain,
    required Map<String, dynamic> types,
    required Map<String, dynamic> message,
    required Uint8List precomputedDigest,
  }) =>
      signDigest(precomputedDigest);
}
