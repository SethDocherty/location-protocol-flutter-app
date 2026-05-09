import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:location_protocol/location_protocol.dart';

/// App-owned read-only RPC adapter for wallet-driven EAS flows.
///
/// This keeps explicit HTTP RPC reads outside wallet transports while exposing
/// typed results close to the upstream `RpcProvider` / `TransactionReceipt`
/// boundary.
class ReadOnlyEasRpcAdapter {
  final String rpcUrl;
  final String easAddress;
  final String schemaRegistryAddress;
  final http.Client? _httpClient;

  const ReadOnlyEasRpcAdapter({
    required this.rpcUrl,
    required this.easAddress,
    required this.schemaRegistryAddress,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  /// Fetches the raw timestamp word for a UID.
  Future<String?> getTimestamp(String uid) async {
    final callData = '0xb8006d96${uid.replaceFirst('0x', '')}';
    try {
      return await _rpcCall('eth_call', [
        {'to': easAddress, 'data': callData},
        'latest',
      ]);
    } catch (_) {
      return null;
    }
  }

  /// Fetches the raw schema record bytes from the schema registry.
  Future<String?> getSchemaRecord(String uid) async {
    final callData = '0xa2ea7c6e${uid.replaceFirst('0x', '')}';
    final result = await _rpcCall('eth_call', [
      {'to': schemaRegistryAddress, 'data': callData},
      'latest',
    ]);
    developer.log('ReadOnlyEasRpcAdapter: getSchemaRecord result: $result');
    return result;
  }

  /// Fetches and decodes a typed transaction receipt.
  Future<TransactionReceipt?> getTransactionReceipt(String txHash) async {
    final result = await _rpcCall('eth_getTransactionReceipt', [txHash]);
    if (result == 'null' || result.isEmpty) return null;

    final receipt = Map<String, dynamic>.from(jsonDecode(result) as Map);
    return TransactionReceipt(
      txHash: receipt['transactionHash']?.toString() ?? txHash,
      blockNumber: _parseHexInt(receipt['blockNumber']),
      status: _parseReceiptStatus(receipt['status']),
      logs: _parseLogs(receipt['logs']),
    );
  }

  /// Polls until the receipt is mined, rejecting reverted transactions.
  Future<TransactionReceipt> waitForReceipt(
    String txHash, {
    int maxRetries = 15,
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      final receipt = await getTransactionReceipt(txHash);
      if (receipt != null) {
        if (receipt.status == false) {
          throw StateError(
            receipt.blockNumber == 0
                ? 'Transaction reverted: $txHash'
                : 'Transaction reverted: $txHash (block ${receipt.blockNumber})',
          );
        }
        return receipt;
      }
      await Future.delayed(pollInterval);
    }

    throw Exception('Timeout waiting for transaction receipt.');
  }

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

  int _parseHexInt(dynamic value) {
    if (value == null) return 0;

    final raw = value.toString();
    if (raw.isEmpty) return 0;
    if (raw.startsWith('0x')) {
      return int.tryParse(raw.substring(2), radix: 16) ?? 0;
    }
    return int.tryParse(raw) ?? 0;
  }

  bool? _parseReceiptStatus(dynamic status) {
    if (status == null) return null;
    if (status is bool) return status;

    final normalized = status.toString().toLowerCase();
    switch (normalized) {
      case '0x1':
      case '1':
      case 'true':
        return true;
      case '0x0':
      case '0':
      case 'false':
        return false;
      default:
        return null;
    }
  }

  List<TransactionLog> _parseLogs(dynamic logsRaw) {
    if (logsRaw is! List) return const <TransactionLog>[];

    return logsRaw
        .whereType<Map>()
        .map(
          (logRaw) => Map<String, dynamic>.from(logRaw),
        )
        .map(
          (log) => TransactionLog(
            address: log['address']?.toString() ?? '',
            topics: log['topics'] is List
                ? (log['topics'] as List)
                    .map((topic) => topic.toString())
                    .toList()
                : const <String>[],
            data: log['data']?.toString() ?? '0x',
          ),
        )
        .toList();
  }
}