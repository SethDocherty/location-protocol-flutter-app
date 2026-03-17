import 'dart:convert';
import 'dart:typed_data';

import 'package:privy_flutter/privy_flutter.dart';

import 'attestation_signer.dart';
import 'ecdsa_signature.dart';

/// A function that performs a single Ethereum JSON-RPC call and returns the
/// string result (typically a 0x-prefixed hex signature).
///
/// Accepting this as a constructor parameter instead of hard-coding Privy's
/// `EmbeddedEthereumWallet` lets [PrivySignerAdapter] be unit-tested without
/// the Privy SDK by injecting a plain Dart mock.
typedef EthereumRpcCaller = Future<String> Function(
  String method,
  List<dynamic> params,
);

/// Thrown when a Privy RPC call fails (e.g. user rejected, network error).
class PrivySigningException implements Exception {
  final String message;

  const PrivySigningException(this.message);

  @override
  String toString() => 'PrivySigningException: $message';
}

/// Adapter that bridges a Privy embedded-wallet RPC to the
/// [AttestationSigner] interface.
///
/// **Design goal — isolation:** All Privy SDK types ([EmbeddedEthereumWallet],
/// [EthereumRpcRequest]) are confined to the [PrivySignerAdapter.fromWallet]
/// factory constructor.  The rest of this class only depends on
/// [EthereumRpcCaller], a plain Dart `typedef`, so protocol logic never has
/// to import Privy.
///
/// **Testability:** In tests, pass a lambda as [rpcCaller]:
/// ```dart
/// final adapter = PrivySignerAdapter(
///   address: '0xf39F…',
///   rpcCaller: (method, params) async => knownHexSig,
/// );
/// ```
///
/// **Production use:**
/// ```dart
/// final adapter = PrivySignerAdapter.fromWallet(embeddedWallet);
/// ```
class PrivySignerAdapter implements AttestationSigner {
  final String _address;
  final EthereumRpcCaller _rpcCaller;

  /// Creates a [PrivySignerAdapter] with an explicit [rpcCaller].
  ///
  /// Prefer [PrivySignerAdapter.fromWallet] in production code;
  /// use this constructor in unit tests to inject a mock caller.
  PrivySignerAdapter({
    required String address,
    required EthereumRpcCaller rpcCaller,
  })  : _address = address,
        _rpcCaller = rpcCaller;

  /// Creates a [PrivySignerAdapter] backed by a real [EmbeddedEthereumWallet].
  ///
  /// This factory is the only place in this file that references Privy SDK
  /// types, keeping the Privy dependency out of the protocol-layer code.
  factory PrivySignerAdapter.fromWallet(EmbeddedEthereumWallet wallet) {
    return PrivySignerAdapter(
      address: wallet.address,
      rpcCaller: (method, params) async {
        final result = await wallet.provider.request(
          EthereumRpcRequest(method: method, params: params),
        );

        late String data;
        result.fold(
          onSuccess: (r) => data = r.data,
          onFailure: (e) =>
              throw PrivySigningException('RPC call failed: ${e.message}'),
        );
        return data;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // AttestationSigner interface
  // ---------------------------------------------------------------------------

  @override
  String get address => _address;

  /// Signs using `eth_signTypedData_v4` (EIP-712 typed data).
  ///
  /// [precomputedDigest] is intentionally **ignored**: the Privy wallet
  /// recomputes `keccak256(0x1901 || domainSeparator || structHash)` itself
  /// from the full typed-data payload, so the signature is directly
  /// recoverable by `EIP712Signer.recoverSigner` without double-hashing.
  ///
  /// The typed-data JSON uses `primary_type` (snake_case) as required by the
  /// Privy Flutter SDK.
  @override
  Future<EcdsaSignature> signTypedData({
    required Map<String, dynamic> domain,
    required Map<String, dynamic> types,
    required Map<String, dynamic> message,
    required Uint8List precomputedDigest,
  }) async {
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
      'primary_type': 'Attest', // Privy Flutter SDK expects snake_case
      'message': message,
    };

    final sigHex = await _rpcCaller(
      'eth_signTypedData_v4',
      [_address, jsonEncode(typedData)],
    );

    return _parseSignature(sigHex);
  }

  /// Signs a raw digest using `personal_sign`.
  ///
  /// Note: `personal_sign` prepends the "\x19Ethereum Signed Message:\n32"
  /// prefix before hashing, so the resulting signature **cannot** be verified
  /// by [EIP712Signer.recoverSigner].  Use [signTypedData] for EIP-712
  /// attestations; reserve this method for cases that explicitly require
  /// personal-sign semantics.
  @override
  Future<MsgSignature> signDigest(Uint8List digest) async {
    final digestHex =
        '0x${digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    final sigHex = await _rpcCaller(
      'personal_sign',
      [digestHex, _address],
    );

    return _parseSignature(sigHex);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Parses a 0x-prefixed 65-byte hex signature into a [MsgSignature].
  ///
  /// Normalises `v` from Ethereum-compact (0 or 1) to EIP-155 (27 or 28).
  static MsgSignature _parseSignature(String sigHex) {
    final clean = sigHex.startsWith('0x') ? sigHex.substring(2) : sigHex;
    if (clean.length != 130) {
      throw FormatException(
        'Expected 65-byte (130 hex char) signature, '
        'got ${clean.length ~/ 2} bytes.',
      );
    }

    final r = BigInt.parse(clean.substring(0, 64), radix: 16);
    final s = BigInt.parse(clean.substring(64, 128), radix: 16);
    var v = int.parse(clean.substring(128, 130), radix: 16);
    if (v < 27) v += 27; // compact 0/1 → EIP-155 27/28

    return MsgSignature(r, s, v);
  }
}
