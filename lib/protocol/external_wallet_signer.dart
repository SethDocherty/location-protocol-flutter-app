import 'dart:typed_data';

import 'package:location_protocol/location_protocol.dart';

/// Callback that shows the typed data to the user for external signing
/// (e.g., via MetaMask) and returns the resulting signature.
typedef ExternalSignCallback = Future<EIP712Signature> Function(
  Map<String, dynamic> typedData,
);

/// Bridges an external wallet (MetaMask, etc.) to the library's [Signer].
///
/// The user is shown the EIP-712 typed data JSON, signs it externally,
/// and pastes the hex signature back. The [onSignTypedData] callback
/// orchestrates this UI flow.
class ExternalWalletSigner extends Signer {
  final String _address;
  final ExternalSignCallback _onSignTypedData;

  ExternalWalletSigner({
    required String walletAddress,
    required ExternalSignCallback onSignTypedData,
  })  : _address = walletAddress,
        _onSignTypedData = onSignTypedData;

  @override
  String get address => _address;

  @override
  Future<EIP712Signature> signTypedData(Map<String, dynamic> typedData) {
    return _onSignTypedData(typedData);
  }

  /// External wallets must use typed data — raw digest signing is unsupported.
  @override
  Future<EIP712Signature> signDigest(Uint8List digest) {
    throw UnsupportedError(
      'ExternalWalletSigner does not support signDigest. '
      'Use signTypedData instead.',
    );
  }
}
