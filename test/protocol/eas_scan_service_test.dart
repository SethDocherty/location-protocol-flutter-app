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
                'schemas': [
                  {'id': '0xabc', 'schema': 'string memo', 'index': 42},
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
}
