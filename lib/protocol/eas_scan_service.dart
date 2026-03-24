import 'dart:convert';
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
      query Schemas($where: SchemaWhereInput) {
        schemas(where: $where, orderBy: [{index: desc}]) {
          id
          schema
          index
        }
      }
    ''';
    final variables = {
      'where': {
        'creator': {'equals': creatorAddress}
      }
    };
    final response = await _client.post(
      Uri.parse(graphqlEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query, 'variables': variables}),
    );
    if (response.statusCode != 200) {
      throw Exception('EAS Scan query failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data.containsKey('errors')) {
      throw Exception('GraphQL error: ${data['errors']}');
    }
    final schemas = (data['data']['schemas'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return schemas.map((s) => RegisteredSchema(
      id: s['id'] as String,
      schema: s['schema'] as String,
      index: s['index'] as int,
    )).toList();
  }
}
