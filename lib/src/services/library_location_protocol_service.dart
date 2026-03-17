// ignore: depend_on_referenced_packages
import 'package:location_protocol/location_protocol.dart';

import '../eas/attestation_signer.dart';
import '../eas/eip712_signer.dart';
import '../models/location_attestation.dart';
import 'location_protocol_service.dart';

/// [LocationProtocolService] implementation backed by the
/// `DecentralizedGeo/location-protocol-dart` library.
///
/// This is the sole [LocationProtocolService] implementation. It currently
/// delegates signing and verification to [EIP712Signer] while referencing the
/// library's public types to confirm the import resolves correctly. Full
/// replacement of [EIP712Signer] with library primitives (e.g.
/// [OffchainSigner], [VerificationResult]) is tracked separately.
///
/// The library exposes, among others:
/// - [EASConstants] — EAS protocol constants (domain name, versions, …)
/// - [ChainConfig] / [ChainAddresses] — per-chain contract addresses
/// - [SchemaDefinition] / [SchemaField] — typed schema model
/// - [LPPayload] — validated Location Protocol base payload
/// - [OffchainSigner] — EIP-712 signing backed by `on_chain`
/// - [VerificationResult] — structured verification output
class LibraryLocationProtocolService implements LocationProtocolService {
  // Library entry-point reference used to verify the import resolves.
  // ignore: unused_field
  static const String _libraryDomainName = EASConstants.eip712DomainName;

  const LibraryLocationProtocolService();

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
