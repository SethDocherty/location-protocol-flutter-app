import '../eas/attestation_signer.dart';
import '../eas/eip712_signer.dart';
import '../models/location_attestation.dart';
import 'location_protocol_service.dart';

/// [LocationProtocolService] implementation that delegates to the existing
/// [EIP712Signer] utilities.
///
/// This is the default implementation when
/// [LocationProtocolConfig.useLocationProtocolLibrary] is `false`.  It
/// preserves all current behaviour exactly — no functional changes are
/// introduced.
class LegacyLocationProtocolService implements LocationProtocolService {
  const LegacyLocationProtocolService();

  @override
  Future<OffchainLocationAttestation> signAttestation({
    required UnsignedLocationAttestation attestation,
    required AttestationSigner signer,
  }) =>
      EIP712Signer.signLocationAttestationWith(
        attestation: attestation,
        signer: signer,
      );

  @override
  String? recoverSigner({
    required OffchainLocationAttestation attestation,
  }) =>
      EIP712Signer.recoverSigner(attestation: attestation);

  @override
  bool verifyAttestation({
    required OffchainLocationAttestation attestation,
  }) =>
      EIP712Signer.verifyLocationAttestation(attestation: attestation);
}
