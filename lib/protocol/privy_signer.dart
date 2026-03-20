import 'dart:convert';
import 'dart:typed_data';

import 'package:location_protocol/location_protocol.dart';
import 'package:privy_flutter/privy_flutter.dart';

/// Callback type for performing Ethereum JSON-RPC calls.
///
/// Accepting this instead of `EmbeddedEthereumWallet` directly lets
/// [PrivySigner] be unit-tested without the Privy SDK.
typedef EthereumRpcCaller = Future<String> Function(
  String method,
  List<dynamic> params,
);

/// Thrown when a Privy RPC call fails.
class PrivySigningException implements Exception {
  final String message;
  const PrivySigningException(this.message);

  @override
  String toString() => 'PrivySigningException: $message';
}

/// Bridges a Privy embedded wallet to the library's [Signer] interface.
///
/// Routes all signing through `eth_signTypedData_v4` — the wallet
/// recomputes the EIP-712 hash internally, so [signDigest] is unsupported.
///
/// The library normalizes `v` to 27/28 inside `OffchainSigner`, so this
/// class does not need to handle v normalization.
///
/// **Production:**
/// ```dart
/// final signer = PrivySigner.fromWallet(embeddedWallet);
/// ```
///
/// **Test:**
/// ```dart
/// final signer = PrivySigner(
///   walletAddress: '0x...',
///   rpcCaller: (method, params) async => '0x...',
/// );
/// ```
class PrivySigner extends Signer {
  final String _address;
  final EthereumRpcCaller _rpcCaller;

  /// Creates a [PrivySigner] with an explicit [rpcCaller] for testability.
  PrivySigner({
    required String walletAddress,
    required EthereumRpcCaller rpcCaller,
  })  : _address = walletAddress,
        _rpcCaller = rpcCaller;

  /// Creates a [PrivySigner] backed by a real Privy [EmbeddedEthereumWallet].
  ///
  /// This factory is the only place that references Privy SDK types.
  factory PrivySigner.fromWallet(EmbeddedEthereumWallet wallet) {
    return PrivySigner(
      walletAddress: wallet.address,
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

  @override
  String get address => _address;

  /// Signs EIP-712 typed data via the Privy wallet's `eth_signTypedData_v4`.
  ///
  /// The [typedData] map is the complete EIP-712 typed data structure
  /// as produced by the library's `OffchainSigner.buildOffchainTypedDataJson()`.
  @override
  Future<EIP712Signature> signTypedData(Map<String, dynamic> typedData) async {
    final sigHex = await _rpcCaller(
      'eth_signTypedData_v4',
      [_address, jsonEncode(typedData)],
    );
    try {
      return EIP712Signature.fromHex(sigHex);
    } catch (e) {
      throw FormatException('Invalid signature: $e');
    }
  }

  /// Wallet signers route exclusively through [signTypedData].
  ///
  /// This method is never called by `OffchainSigner` when `signTypedData`
  /// is overridden.
  @override
  Future<EIP712Signature> signDigest(Uint8List digest) {
    throw UnsupportedError(
      'PrivySigner does not support signDigest. '
      'Use signTypedData via OffchainSigner instead.',
    );
  }
}
