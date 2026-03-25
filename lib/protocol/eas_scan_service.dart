import 'dart:convert';
import 'package:eip55/eip55.dart';
import 'package:http/http.dart' as http;

class RegisteredSchema {
  final String id;     // The schema UID (0x-prefixed)
  final String schema; // EAS schema string e.g. "uint256 eventTimestamp,string memo"
  final int index;

  const RegisteredSchema({required this.id, required this.schema, required this.index});
}

class EasScanService {
  final http.Client _client;
  final String graphqlEndpoint; // e.g. 'https://sepolia.easscan.org/graphql'

  EasScanService({required this.graphqlEndpoint, http.Client? client})
      : _client = client ?? http.Client();

  /// Returns all schemas created by [creatorAddress] on this chain.
  Future<List<RegisteredSchema>> queryUserSchemas(String creatorAddress) async {
    const query = r'''
      query Schemata($where: SchemaWhereInput) {
        schemata(where: $where) {
          id
          schema
          index
        }
      }
    ''';
    // EAS Scan is case-sensitive: requires EIP-55 checksummed address.
    final checksumAddress = toChecksumAddress(creatorAddress);
    final variables = {
      'where': {
        'creator': {'equals': checksumAddress}
      }
    };
    final body = jsonEncode({'query': query, 'variables': variables, 'operationName': 'Schemata'});
    // debugPrint('EAS Query Body: $body');
    final response = await _client.post(
      Uri.parse(graphqlEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('EAS Scan query failed: ${response.statusCode} — ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data.containsKey('errors')) {
      throw Exception('GraphQL error: ${data['errors']}');
    }
    final schemas = (data['data']['schemata'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return schemas.map((s) => RegisteredSchema(
      id: s['id'] as String,
      schema: s['schema'] as String,
      index: int.parse(s['index'].toString()),
    )).toList();
  }
}
