import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/read_only_eas_rpc_adapter.dart';

void main() {
  const rpcUrl = 'https://configured.rpc';
  const easAddress = '0x00000000000000000000000000000000000000ea';
  const schemaRegistryAddress = '0x00000000000000000000000000000000000000ab';

  group('ReadOnlyEasRpcAdapter', () {
    late List<Map<String, String>> capturedRequests;

    setUp(() {
      capturedRequests = [];
    });

    ReadOnlyEasRpcAdapter buildAdapter(String responseBody) {
      return ReadOnlyEasRpcAdapter(
        rpcUrl: rpcUrl,
        easAddress: easAddress,
        schemaRegistryAddress: schemaRegistryAddress,
        httpClient: FakeClient((request) async {
          final body = request is http.Request ? request.body : '';
          capturedRequests.add({
            'url': request.url.toString(),
            'body': body,
          });
          return http.Response(responseBody, 200);
        }),
      );
    }

    test('getSchemaRecord uses the schema registry address', () async {
      final adapter = buildAdapter(
        '{"jsonrpc":"2.0","id":1,"result":"0x1234"}',
      );

      final result = await adapter.getSchemaRecord('0x${'ab' * 32}');

      expect(result, '0x1234');
      expect(capturedRequests, hasLength(1));
      expect(capturedRequests.single['url'], rpcUrl);
      expect(
        capturedRequests.single['body'],
        contains('"to":"$schemaRegistryAddress"'),
      );
    });

    test('getTimestamp uses the EAS address', () async {
      final adapter = buildAdapter(
        '{"jsonrpc":"2.0","id":1,"result":"0x5678"}',
      );

      final result = await adapter.getTimestamp('0x${'cd' * 32}');

      expect(result, '0x5678');
      expect(capturedRequests.single['body'], contains('"to":"$easAddress"'));
    });

    test('getTransactionReceipt decodes a typed receipt', () async {
      final adapter = buildAdapter(
        '{"jsonrpc":"2.0","id":1,"result":{"transactionHash":"0xabc","blockNumber":"0x2","status":"0x1","logs":[{"address":"$easAddress","topics":["${EASConstants.attestedEventTopic}"],"data":"0x${'12' * 32}"}]}}',
      );

      final receipt = await adapter.getTransactionReceipt('0xabc');

      expect(receipt, isNotNull);
      expect(receipt!.txHash, '0xabc');
      expect(receipt.blockNumber, 2);
      expect(receipt.status, isTrue);
      expect(receipt.logs, hasLength(1));
      expect(receipt.logs.single.address, easAddress);
      expect(receipt.logs.single.topics.single, EASConstants.attestedEventTopic);
    });

    test('waitForReceipt polls until a receipt is mined', () async {
      int pollCount = 0;
      final adapter = ReadOnlyEasRpcAdapter(
        rpcUrl: rpcUrl,
        easAddress: easAddress,
        schemaRegistryAddress: schemaRegistryAddress,
        httpClient: FakeClient((request) async {
          final body = request is http.Request ? request.body : '';
          capturedRequests.add({
            'url': request.url.toString(),
            'body': body,
          });
          if (pollCount++ == 0) {
            return http.Response('{"jsonrpc":"2.0","id":1,"result":null}', 200);
          }
          return http.Response(
            '{"jsonrpc":"2.0","id":1,"result":{"transactionHash":"0xtx","blockNumber":"0x3","status":"0x1","logs":[]}}',
            200,
          );
        }),
      );

      final receipt = await adapter.waitForReceipt(
        '0xtx',
        pollInterval: const Duration(milliseconds: 1),
      );

      expect(receipt.txHash, '0xtx');
      expect(receipt.blockNumber, 3);
      expect(pollCount, 2);
    });

    test('waitForReceipt rejects reverted receipts', () async {
      final adapter = buildAdapter(
        '{"jsonrpc":"2.0","id":1,"result":{"transactionHash":"0xdead","blockNumber":"0x4","status":"0x0","logs":[]}}',
      );

      await expectLater(
        adapter.waitForReceipt('0xdead'),
        throwsStateError,
      );
    });
  });
}

class FakeClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;

  FakeClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}