import 'dart:typed_data';

import 'package:location_protocol/location_protocol.dart';

import 'schema_config.dart';

/// Orchestrates all protocol operations for the app.
///
/// Offchain operations work with any [Signer]. Onchain operations use
/// either the static builder pipeline (for wallet-based signers like
/// [PrivySigner]) or instance methods (for private-key flows).
class AttestationService {
  final Signer signer;
  final int chainId;
  final String _easAddress;
  final OffchainSigner _offchainSigner;

  AttestationService({
    required this.signer,
    required this.chainId,
  })  : _easAddress = ChainConfig.forChainId(chainId)!.eas,
        _offchainSigner = OffchainSigner(
          signer: signer,
          chainId: chainId,
          easContractAddress: ChainConfig.forChainId(chainId)!.eas,
        );

  /// Signs an offchain location attestation.
  Future<SignedOffchainAttestation> signOffchain({
    required double lat,
    required double lng,
    required String memo,
    BigInt? eventTimestamp,
  }) {
    final lpPayload = AppSchema.buildLPPayload(lat: lat, lng: lng);
    final userData = AppSchema.buildUserData(
      memo: memo,
      eventTimestamp: eventTimestamp,
    );

    return _offchainSigner.signOffchainAttestation(
      schema: AppSchema.definition,
      lpPayload: lpPayload,
      userData: userData,
    );
  }

  /// Verifies an offchain attestation. Returns synchronously.
  VerificationResult verifyOffchain(SignedOffchainAttestation attestation) {
    return _offchainSigner.verifyOffchainAttestation(attestation);
  }

  // --- Onchain: static builder pipeline (for wallet signers) ---

  /// Builds calldata for an onchain attestation (wallet path).
  Uint8List buildAttestCallData({
    required double lat,
    required double lng,
    required String memo,
    BigInt? eventTimestamp,
  }) {
    return EASClient.buildAttestCallData(
      schema: AppSchema.definition,
      lpPayload: AppSchema.buildLPPayload(lat: lat, lng: lng),
      userData: AppSchema.buildUserData(
        memo: memo,
        eventTimestamp: eventTimestamp,
      ),
    );
  }

  /// Builds calldata for timestamping an offchain UID (wallet path).
  Uint8List buildTimestampCallData(String uid) {
    return EASClient.buildTimestampCallData(uid);
  }

  /// Builds calldata for schema registration (wallet path).
  Uint8List buildRegisterSchemaCallData() {
    return SchemaRegistryClient.buildRegisterCallData(AppSchema.definition);
  }

  /// Wraps calldata into a wallet-friendly tx request map.
  Map<String, dynamic> buildTxRequest({
    required Uint8List callData,
    required String contractAddress,
  }) {
    return TxUtils.buildTxRequest(
      to: contractAddress,
      data: callData,
      from: signer.address,
    );
  }

  /// The EAS contract address for the current chain.
  String get easAddress => _easAddress;

  /// The Schema Registry contract address for the current chain.
  String get schemaRegistryAddress =>
      ChainConfig.forChainId(chainId)!.schemaRegistry;
}
