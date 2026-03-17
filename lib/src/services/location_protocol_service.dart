import '../eas/attestation_signer.dart';
import '../models/location_attestation.dart';

/// Service interface for Location Protocol attestation operations.
///
/// Decouples the UI and calling code from the underlying signing and
/// verification implementation.  The sole concrete implementation is
/// [LibraryLocationProtocolService], which is wired up automatically by
/// [LocationProtocolProvider].
///
/// Callers should obtain the active instance from [LocationProtocolProvider]:
/// ```dart
/// final service = LocationProtocolProvider.of(context);
/// ```
abstract class LocationProtocolService {
  /// Signs [attestation] using [signer] and returns the resulting signed
  /// offchain attestation.
  Future<OffchainLocationAttestation> signAttestation({
    required UnsignedLocationAttestation attestation,
    required AttestationSigner signer,
  });

  /// Recovers the Ethereum address that produced the signature in
  /// [attestation], or `null` if recovery fails.
  String? recoverSigner({
    required OffchainLocationAttestation attestation,
  });

  /// Returns `true` when the attestation's signature is valid and the
  /// recovered address matches [OffchainLocationAttestation.signer].
  bool verifyAttestation({
    required OffchainLocationAttestation attestation,
  });
}
