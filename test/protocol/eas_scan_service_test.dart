import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:location_protocol_flutter_app/protocol/eas_scan_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://fallback.example.com'));
  });

  setUp(() {
    mockClient = MockHttpClient();
  });

  group('EasScanService', () {
    test('queryUserSchemas returns parsed schemas on success', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'data': {
                'schemata': [
                  {'id': '0xabc', 'schema': 'string memo', 'index': '42'},
                ],
              },
            }),
            200,
          ));

      final service = EasScanService(
        graphqlEndpoint: 'https://sepolia.easscan.org/graphql',
        client: mockClient,
      );

      final results = await service.queryUserSchemas('0xDeadBeef');
      expect(results.length, 1);
      expect(results.first.id, '0xabc');
      expect(results.first.schema, 'string memo');
      expect(results.first.index, 42);
    });

    test('queryUserSchemas throws on non-200 response', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Error', 500));

      final service = EasScanService(
        graphqlEndpoint: 'https://sepolia.easscan.org/graphql',
        client: mockClient,
      );
      expect(
        () => service.queryUserSchemas('0xDeadBeef'),
        throwsException,
      );
    });

    test('queryUserSchemas throws on GraphQL errors field', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'errors': [{'message': 'bad query'}]}),
            200,
          ));

      final service = EasScanService(
        graphqlEndpoint: 'https://sepolia.easscan.org/graphql',
        client: mockClient,
      );
      expect(
        () => service.queryUserSchemas('0xDeadBeef'),
        throwsException,
      );
    });
  });

  test('queryUserSchemas checksums lowercase address before querying', () async {
    String? capturedBody;
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((invocation) async {
      capturedBody = invocation.namedArguments[const Symbol('body')] as String;
      return http.Response(
        jsonEncode({'data': {'schemata': []}}),
        200,
      );
    });

    final service = EasScanService(
      graphqlEndpoint: 'https://base-sepolia.easscan.org/graphql',
      client: mockClient,
    );

    // Pass lowercase address — the API requires the checksummed form.
    await service.queryUserSchemas('0x3074c8732366ce5db80986aba8fb69897872ddb9');

    final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
    final sentAddress =
        body['variables']['where']['creator']['equals'] as String;
    // Must be checksummed, not lowercase.
    expect(sentAddress, '0x3074C8732366cE5DB80986aBA8FB69897872DdB9');
  });
}
