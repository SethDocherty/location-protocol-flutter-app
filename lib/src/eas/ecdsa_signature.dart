/// An ECDSA signature produced by an [AttestationSigner].
///
/// Replaces the `web3dart` `MsgSignature` type.  The `v` component follows
/// the Ethereum convention: 27 or 28 (not the raw recovery ID of 0 or 1).
class EcdsaSignature {
  /// The R component of the signature.
  final BigInt r;

  /// The S component of the signature.
  final BigInt s;

  /// The recovery ID in Ethereum convention (27 or 28).
  final int v;

  const EcdsaSignature(this.r, this.s, this.v);
}
