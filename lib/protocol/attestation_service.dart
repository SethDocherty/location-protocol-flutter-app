import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
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
  final String rpcUrl;
  final http.Client? _httpClient;
  final String _easAddress;
  final OffchainSigner _offchainSigner;
  final bool sponsorGas;

  AttestationService({
    required this.signer,
    required this.chainId,
    required this.rpcUrl,
    this.sponsorGas = false,
    http.Client? httpClient,
  })  : _httpClient = httpClient,
        _easAddress = ChainConfig.forChainId(chainId)!.eas,
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

  /// Checks if the current app schema is registered on-chain.
  Future<bool> isSchemaRegistered() async {
    final uid = AppSchema.schemaUID.toLowerCase();
    final record = await getSchemaRecord(uid);
    if (record == null || record.length < 66) return false;

    // In EAS, getSchema returns a `SchemaRecord` struct. Because this struct contains a dynamic 
    // string, the entire return value is ABI-encoded as a dynamic type. This means the return data
    // typically starts with a 32-byte offset (0x20) pointing to the actual struct data.
    // The UID is the first 32 bytes of the struct data.
    String returnedUid;
    if (record.length >= 130 && record.startsWith('0x0000000000000000000000000000000000000000000000000000000000000020')) {
      returnedUid = '0x${record.substring(66, 130)}'.toLowerCase();
    } else {
      // Fallback in case the record doesn't start with the expected offset
      returnedUid = record.substring(0, 66).toLowerCase();
    }
    
    return returnedUid == uid;
  }

  /// Checks if a UID has already been timestamped onchain.
  Future<bool> isTimestamped(String uid) async {
    final timestamp = await getTimestamp(uid);
    if (timestamp == null || timestamp.isEmpty) return false;
    // Returns 32 bytes of 0 if not set.
    return timestamp != '0x0000000000000000000000000000000000000000000000000000000000000000';
  }

  /// Fetches the raw timestamp record for a UID.
  Future<String?> getTimestamp(String uid) async {
    // timestamps(bytes32) selector: 0xb8006d96
    final callData = '0xb8006d96${uid.replaceFirst('0x', '')}';
    try {
      return await _rpcCall('eth_call', [
        {'to': easAddress, 'data': callData},
        'latest'
      ]);
    } catch (_) {
      return null;
    }
  }

  /// Fetches a raw schema record from the registry.
  Future<String?> getSchemaRecord(String uid) async {
    // getSchema(bytes32) selector: 0xa2ea7c6e (official EAS SchemaRegistry)
    final callData = '0xa2ea7c6e${uid.replaceFirst('0x', '')}';

    final result = await _rpcCall('eth_call', [
      {'to': schemaRegistryAddress, 'data': callData},
      'latest'
    ]);
    developer.log('AttestationService: getSchemaRecord result: $result');
    return result;
  }

  /// Fetches a transaction receipt.
  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) async {
    final result = await _rpcCall('eth_getTransactionReceipt', [txHash]);
    // JSON-RPC returns null literal for missing receipt.
    if (result == 'null' || result.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(result));
  }

  /// Polls for a transaction receipt and extracts the EAS Attestation UID.
  Future<String> waitForAttestationUid(
    String txHash, {
    int maxRetries = 15,
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
        final receipt = await getTransactionReceipt(txHash);
        if (receipt != null) {
            final logs = receipt['logs'] as List<dynamic>?;
            if (logs != null) {
              for (final logRaw in logs) {
                final log = logRaw as Map<String, dynamic>;
                final address = log['address'] as String?;
                if (address != null && address.toLowerCase() == _easAddress.toLowerCase()) {
                  final data = log['data'] as String?;
                  if (data != null && data.length >= 66) {
                    return data.substring(0, 66);
                  }
                }
              }
            }
            throw Exception('Transaction mined but no Attested event found.');
        }
        await Future.delayed(pollInterval);
    }
    throw Exception('Timeout waiting for transaction receipt.');
  }

  /// Performs an RPC call, falling back to HTTP if the signer's provider fails.
  Future<String> _rpcCall(String method, List<dynamic> params) async {
    if (rpcUrl.isEmpty) {
      throw UnsupportedError(
        'Read-only checks require an RPC URL in Settings.',
      );
    }

    final client = _httpClient ?? http.Client();
    try {
      final response = await client.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': DateTime.now().millisecondsSinceEpoch,
          'method': method,
          'params': params,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('RPC failed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('error')) {
        throw Exception('RPC Error: ${data['error']['message']}');
      }

      final result = data['result'];
      if (result == null) return 'null';
      if (result is String) return result;
      return jsonEncode(result);
    } finally {
      if (_httpClient == null) client.close();
    }
  }
}
