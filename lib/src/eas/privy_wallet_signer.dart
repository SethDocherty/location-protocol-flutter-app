import 'dart:convert';
import 'dart:typed_data';

import 'package:privy_flutter/privy_flutter.dart';
import 'package:web3dart/web3dart.dart';

import 'attestation_signer.dart';

/// Signs digests using a Privy embedded Ethereum wallet.
///
/// @deprecated Use `PrivySignerAdapter.fromWallet` instead.
/// `PrivySignerAdapter` offers the same functionality with an injectable
/// `EthereumRpcCaller` that enables unit testing without the Privy SDK and
/// clearly isolates Privy SDK types from protocol logic.
///
/// ```dart
/// // Before:
/// final signer = PrivyWalletSigner(embeddedWallet);
///
/// // After:
/// final signer = PrivySignerAdapter.fromWallet(embeddedWallet);
/// ```
@Deprecated('Use PrivySignerAdapter.fromWallet instead.')
class PrivyWalletSigner implements AttestationSigner {
  final EmbeddedEthereumWallet _wallet;

  PrivyWalletSigner(this._wallet);

  @override
  String get address => _wallet.address;

  // ---------------------------------------------------------------------------
  // Primary signing path — use eth_signTypedData_v4 (EIP-712).
  // ---------------------------------------------------------------------------

  /// Signs using `eth_signTypedData_v4`.
  ///
  /// [precomputedDigest] is intentionally ignored: we let the Privy wallet
  /// hash the typed data so the signature is directly recoverable via
  /// [EIP712Signer.recoverSigner] (which calls `ecRecover` on the same
  /// EIP-712 digest).
  @override
  Future<MsgSignature> signTypedData({
    required Map<String, dynamic> domain,
    required Map<String, dynamic> types,
    required Map<String, dynamic> message,
    required Uint8List precomputedDigest,
  }) async {
    // eth_signTypedData_v4 expects the full typed-data payload as a JSON
    // string (second param).  The wallet computes keccak256(0x1901 ||
    // domainSeparator || structHash) and signs it directly — no
    // personal_sign prefix.
    final typedData = {
      'domain': domain,
      'types': {
        // EIP-712 requires EIP712Domain in the types map.
        'EIP712Domain': [
          {'name': 'name', 'type': 'string'},
          {'name': 'version', 'type': 'string'},
          {'name': 'chainId', 'type': 'uint256'},
          {'name': 'verifyingContract', 'type': 'address'},
        ],
        ...types,
      },
      'primary_type': 'Attest',
      'message': message,
    };

    final result = await _wallet.provider.request(
      EthereumRpcRequest(
        method: 'eth_signTypedData_v4',
        params: [_wallet.address, jsonEncode(typedData)],
      ),
    );

    late MsgSignature signature;

    result.fold(
      onSuccess: (response) {
        signature = _parseSignature(response.data);
      },
      onFailure: (error) {
        throw Exception('Privy signing failed: ${error.message}');
      },
    );

    return signature;
  }

  // ---------------------------------------------------------------------------
  // Low-level fallback — kept for API compatibility but NOT called by
  // EIP712Signer.signLocationAttestationWith (which uses signTypedData).
  // ---------------------------------------------------------------------------

  @override
  Future<MsgSignature> signDigest(Uint8List digest) async {
    // personal_sign adds "\x19Ethereum Signed Message:\n32" before hashing,
    // which breaks EIP-712 verification.  This path should only be used when
    // the caller truly wants a personal-sign-prefixed signature.
    final digestHex =
        '0x${digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    final result = await _wallet.provider.request(
      EthereumRpcRequest(
        method: 'personal_sign',
        params: [digestHex, _wallet.address],
      ),
    );

    late MsgSignature signature;

    result.fold(
      onSuccess: (response) {
        signature = _parseSignature(response.data);
      },
      onFailure: (error) {
        throw Exception('Privy signing failed: ${error.message}');
      },
    );

    return signature;
  }

  /// Parses a 65-byte hex signature into (r, s, v).
  static MsgSignature _parseSignature(String sigHex) {
    final clean = sigHex.startsWith('0x') ? sigHex.substring(2) : sigHex;
    if (clean.length != 130) {
      throw FormatException(
        'Expected 65-byte signature, got ${clean.length ~/ 2} bytes',
      );
    }

    final r = BigInt.parse(clean.substring(0, 64), radix: 16);
    final s = BigInt.parse(clean.substring(64, 128), radix: 16);
    var v = int.parse(clean.substring(128, 130), radix: 16);
    if (v < 27) v += 27;

    return MsgSignature(r, s, v);
  }
}
