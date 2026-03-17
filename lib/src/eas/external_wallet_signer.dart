/// An [AttestationSigner] that delegates signing to an external wallet
/// (e.g. MetaMask) via a caller-supplied callback.
///
/// Unlike `PrivySignerAdapter` — which signs in-app via Privy's embedded
/// wallet RPC — this signer serializes the EIP-712 typed data to JSON,
/// passes it to [onSignRequest], and waits for the caller to return the
/// hex signature string.  The callback is typically implemented as a
/// bottom-sheet/dialog that shows the user a MetaMask JS snippet to run in
/// a browser console, then collects the pasted signature.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:web3dart/web3dart.dart';

import 'attestation_signer.dart';

/// Signs EIP-712 attestations using an external wallet (copy/paste flow).
class ExternalWalletSigner implements AttestationSigner {
  @override
  final String address;

  /// Called by [signTypedData] with the signer's address and the full
  /// EIP-712 typed-data payload serialized as a JSON string.
  ///
  /// The implementation should show the user a UI that lets them sign the
  /// data (e.g. via MetaMask's `eth_signTypedData_v4`) and returns the
  /// resulting 0x-prefixed 132-character hex signature.
  ///
  /// Throw (or return an error string that fails validation) to cancel.
  final Future<String> Function(String walletAddress, String jsonTypedData)
      onSignRequest;

  ExternalWalletSigner({
    required this.address,
    required this.onSignRequest,
  });

  // ---------------------------------------------------------------------------
  // AttestationSigner interface
  // ---------------------------------------------------------------------------

  /// Not used — external wallets always sign via [signTypedData].
  @override
  Future<MsgSignature> signDigest(Uint8List digest) {
    throw UnsupportedError(
      'ExternalWalletSigner does not support raw-digest signing. '
      'Use signTypedData (EIP-712) instead.',
    );
  }

  /// Serializes [domain] / [types] / [message] to the standard EIP-712 JSON
  /// format expected by `eth_signTypedData_v4`, hands it to [onSignRequest],
  /// then parses the returned hex signature into a [MsgSignature].
  ///
  /// Note: uses `primaryType` (camelCase) — the standard browser wallet key.
  /// Privy's Kotlin SDK requires `primary_type` (snake_case), but MetaMask
  /// and other browser wallets expect camelCase.
  @override
  Future<MsgSignature> signTypedData({
    required Map<String, dynamic> domain,
    required Map<String, dynamic> types,
    required Map<String, dynamic> message,
    required Uint8List precomputedDigest,
  }) async {
    final typedData = {
      'domain': domain,
      'types': {
        'EIP712Domain': [
          {'name': 'name', 'type': 'string'},
          {'name': 'version', 'type': 'string'},
          {'name': 'chainId', 'type': 'uint256'},
          {'name': 'verifyingContract', 'type': 'address'},
        ],
        ...types,
      },
      'primaryType': 'Attest',
      'message': message,
    };

    final sigHex = await onSignRequest(address, jsonEncode(typedData));
    return _parseSignature(sigHex);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static MsgSignature _parseSignature(String hexSig) {
    final hex =
        hexSig.startsWith('0x') ? hexSig.substring(2) : hexSig;
    if (hex.length != 130) {
      throw FormatException(
        'Expected 65-byte (130 hex char) signature, got ${hex.length} chars.',
      );
    }
    final r = BigInt.parse(hex.substring(0, 64), radix: 16);
    final s = BigInt.parse(hex.substring(64, 128), radix: 16);
    int v = int.parse(hex.substring(128, 130), radix: 16);
    // eth_signTypedData_v4 returns v as 0/1; ecRecover expects 27/28.
    if (v < 27) v += 27;
    return MsgSignature(r, s, v);
  }
}
