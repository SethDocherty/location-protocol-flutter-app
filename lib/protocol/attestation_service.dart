import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:location_protocol/location_protocol.dart';

import 'read_only_eas_rpc_adapter.dart';
import 'schema_config.dart';

/// Orchestrates all protocol operations for the app.
///
/// Offchain operations work with any [Signer]. Onchain operations use
/// either the static builder pipeline (for wallet-based signers like
/// [PrivySigner]) or instance methods (for private-key flows).
class AttestationService {
  static const int _bytes32HexLength = 66;

  final Signer signer;
  final int chainId;
  final String rpcUrl;
  final String _easAddress;
  final OffchainSigner _offchainSigner;
  final bool sponsorGas;
  final ReadOnlyEasRpcAdapter _readOnlyRpc;

  AttestationService({
    required this.signer,
    required this.chainId,
    required this.rpcUrl,
    this.sponsorGas = false,
    http.Client? httpClient,
  })  : _easAddress = ChainConfig.forChainId(chainId)!.eas,
        _offchainSigner = OffchainSigner(
          signer: signer,
          chainId: chainId,
          easContractAddress: ChainConfig.forChainId(chainId)!.eas,
        ),
        _readOnlyRpc = ReadOnlyEasRpcAdapter(
          rpcUrl: rpcUrl,
          easAddress: ChainConfig.forChainId(chainId)!.eas,
          schemaRegistryAddress: ChainConfig.forChainId(chainId)!.schemaRegistry,
          httpClient: httpClient,
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

  /// Signs an offchain attestation with an explicit userData map.
  /// Use this for dynamic schemas where userData is built from user inputs.
  Future<SignedOffchainAttestation> signOffchainWithData({
    required SchemaDefinition schema,
    required double lat,
    required double lng,
    required Map<String, dynamic> userData,
  }) {
    final lpPayload = AppSchema.buildLPPayload(lat: lat, lng: lng);
    return _offchainSigner.signOffchainAttestation(
      schema: schema,
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

  /// Builds onchain attest calldata with an explicit userData map.
  /// Use this for dynamic schemas where userData is built from user inputs.
  Uint8List buildAttestCallDataWithUserData({
    required SchemaDefinition schema,
    required double lat,
    required double lng,
    required Map<String, dynamic> userData,
  }) {
    return EASClient.buildAttestCallData(
      schema: schema,
      lpPayload: AppSchema.buildLPPayload(lat: lat, lng: lng),
      userData: userData,
    );
  }

  /// Builds calldata for timestamping an offchain UID (wallet path).
  Uint8List buildTimestampCallData(String uid) {
    return EASClient.buildTimestampCallData(uid);
  }

  /// Builds calldata for schema registration (wallet path).
  Uint8List buildRegisterSchemaCallData([SchemaDefinition? schema]) {
    return SchemaRegistryClient.buildRegisterCallData(schema ?? AppSchema.definition);
  }

  /// Wraps calldata into a wallet-friendly tx request map.
  ///
  /// Includes `chainId` as a 0x-prefixed hex string, required by Privy's
  /// Android SDK for `eth_sendTransaction`.
  Map<String, dynamic> buildTxRequest({
    required Uint8List callData,
    required String contractAddress,
  }) {
    final tx = TxUtils.buildTxRequest(
      to: contractAddress,
      data: callData,
      from: signer.address,
    );
    // Privy Android SDK requires chainId in the tx object (EIP-155).
    final enhancedTx = {...tx, 'chainId': '0x${chainId.toRadixString(16)}'};
    if (sponsorGas) {
      enhancedTx['sponsor'] = true;
    }
    return enhancedTx;
  }

  /// The EAS contract address for the current chain.
  String get easAddress => _easAddress;

  /// The Schema Registry contract address for the current chain.
  String get schemaRegistryAddress =>
      ChainConfig.forChainId(chainId)!.schemaRegistry;

  /// Generalized registration check — works for any schema UID.
  Future<bool> isSchemaUidRegistered(String uid) async {
    final normalizedUid = uid.toLowerCase().startsWith('0x')
        ? uid.toLowerCase()
        : '0x${uid.toLowerCase()}';
    final record = await getSchemaRecord(normalizedUid);
    if (record == null || record.length < 66) return false;

    // In EAS, getSchema returns a `SchemaRecord` struct. Because this struct contains a dynamic
    // string, the entire return value is ABI-encoded as a dynamic type. This means the return data
    // typically starts with a 32-byte offset (0x20) pointing to the actual struct data.
    // The UID is the first 32 bytes of the struct data.
    String returnedUid;
    if (record.length >= 130 &&
        record.startsWith(
            '0x0000000000000000000000000000000000000000000000000000000000000020')) {
      returnedUid = '0x${record.substring(66, 130)}'.toLowerCase();
    } else {
      // Fallback in case the record doesn't start with the expected offset
      returnedUid = record.substring(0, 66).toLowerCase();
    }

    return returnedUid == normalizedUid;
  }

  /// Checks if the current app schema is registered on-chain.
  Future<bool> isSchemaRegistered() =>
      isSchemaUidRegistered(AppSchema.schemaUID);

  /// Checks if a UID has already been timestamped onchain.
  Future<bool> isTimestamped(String uid) async {
    final timestamp = await getTimestamp(uid);
    if (timestamp == null || timestamp.isEmpty) return false;
    // Returns 32 bytes of 0 if not set.
    return timestamp != '0x0000000000000000000000000000000000000000000000000000000000000000';
  }

  /// Fetches the raw timestamp record for a UID.
  Future<String?> getTimestamp(String uid) async {
    return _readOnlyRpc.getTimestamp(uid);
  }

  /// Fetches a raw schema record from the registry.
  Future<String?> getSchemaRecord(String uid) async {
    return _readOnlyRpc.getSchemaRecord(uid);
  }

  /// Fetches a transaction receipt.
  Future<TransactionReceipt?> getTransactionReceipt(String txHash) {
    return _readOnlyRpc.getTransactionReceipt(txHash);
  }

  /// Polls for a transaction receipt and extracts the EAS Attestation UID.
  Future<String> waitForAttestationUid(
    String txHash, {
    int maxRetries = 15,
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final receipt = await _readOnlyRpc.waitForReceipt(
      txHash,
      maxRetries: maxRetries,
      pollInterval: pollInterval,
    );
    return _extractAttestedUid(receipt);
  }

  String _extractAttestedUid(TransactionReceipt receipt) {
    if (receipt.logs.isEmpty) {
      throw StateError(
        'No Attested event found in receipt logs from $_easAddress',
      );
    }

    final lowerAddress = _easAddress.toLowerCase();
    for (final log in receipt.logs) {
      if (log.address.toLowerCase() == lowerAddress &&
          log.topics.isNotEmpty &&
          log.topics.first == EASConstants.attestedEventTopic) {
        final data = log.data;
        if (data.startsWith('0x') && data.length >= _bytes32HexLength) {
          return data.substring(0, _bytes32HexLength);
        }

        throw StateError(
          'Attested event data does not contain a bytes32 UID: $data',
        );
      }
    }

    throw StateError(
      'No Attested event found in receipt logs from $_easAddress',
    );
  }

}
