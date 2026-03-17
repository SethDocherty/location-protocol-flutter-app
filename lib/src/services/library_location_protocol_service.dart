// ignore: depend_on_referenced_packages
import 'package:location_protocol/location_protocol.dart';

import '../eas/attestation_signer.dart';
import '../models/location_attestation.dart';
import 'legacy_location_protocol_service.dart';
import 'location_protocol_service.dart';

/// [LocationProtocolService] implementation backed by the
/// `DecentralizedGeo/location-protocol-dart` library.
///
/// This implementation is activated when
/// [LocationProtocolConfig.useLocationProtocolLibrary] is `true`.
///
/// **Current state:** initial scaffold — the library is imported and its types
/// are referenced here, but all operations delegate to
/// [LegacyLocationProtocolService] until the full migration is completed in a
/// subsequent issue.  This keeps the feature flag safe to flip on for
/// evaluation without any behavioural change.
///
/// The library exposes, among others:
/// - [EASConstants] — EAS protocol constants (domain name, versions, …)
/// - [ChainConfig] / [ChainAddresses] — per-chain contract addresses
/// - [SchemaDefinition] / [SchemaField] — typed schema model
/// - [LPPayload] — validated Location Protocol base payload
/// - [OffchainSigner] — EIP-712 signing backed by `on_chain`
/// - [VerificationResult] — structured verification output
class LibraryLocationProtocolService implements LocationProtocolService {
  // Library entry-point references used to verify the import resolves.
  // ignore: unused_field
  static const String _libraryDomainName = EASConstants.eip712DomainName;

  final LocationProtocolService _delegate;

  /// Creates the service.
  ///
  /// [delegate] is used for all operations until the library migration is
  /// complete; defaults to [LegacyLocationProtocolService].
  LibraryLocationProtocolService({LocationProtocolService? delegate})
      : _delegate = delegate ?? const LegacyLocationProtocolService();

  @override
  Future<OffchainLocationAttestation> signAttestation({
    required UnsignedLocationAttestation attestation,
    required AttestationSigner signer,
  }) =>
      // TODO(#2): Replace with library-backed signing once the migration
      // from web3dart to on_chain/blockchain_utils is complete.
      _delegate.signAttestation(attestation: attestation, signer: signer);

  @override
  String? recoverSigner({
    required OffchainLocationAttestation attestation,
  }) =>
      // TODO(#2): Replace with OffchainSigner.verifyOffchainAttestation.
      _delegate.recoverSigner(attestation: attestation);

  @override
  bool verifyAttestation({
    required OffchainLocationAttestation attestation,
  }) =>
      // TODO(#2): Use VerificationResult.isValid from the library.
      _delegate.verifyAttestation(attestation: attestation);
}
