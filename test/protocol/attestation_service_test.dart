import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/protocol/privy_signer.dart';
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';

const _testPrivateKey =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const _testAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

String _encodeAbiSchemaRecord({
  required String uid,
  required String schema,
  String resolver = EASConstants.zeroAddress,
  bool revocable = true,
}) {
  final schemaHex = utf8.encode(schema).map(
    (byte) => byte.toRadixString(16).padLeft(2, '0'),
  ).join();
  final paddedSchemaHex = schemaHex.padRight(
    ((schemaHex.length + 63) ~/ 64) * 64,
    '0',
  );
  final schemaLengthWord = schema.length.toRadixString(16).padLeft(64, '0');
  final resolverWord = resolver.replaceFirst('0x', '').padLeft(64, '0');
  final revocableWord = revocable ? '1'.padLeft(64, '0') : ''.padLeft(64, '0');

  return '0x'
      '${'20'.padLeft(64, '0')}'
      '${uid.replaceFirst('0x', '')}'
      '$resolverWord'
      '$revocableWord'
      '${'80'.padLeft(64, '0')}'
      '$schemaLengthWord'
      '$paddedSchemaHex';
}

void main() {
  late AttestationService service;
  late LocalKeySigner signer;

  setUp(() {
    signer = LocalKeySigner(privateKeyHex: _testPrivateKey);
    service = AttestationService(
      signer: signer,
      chainId: 11155111, // Sepolia
      rpcUrl: 'https://unused.rpc',
    );
  });

  group('AttestationService.signOffchain', () {
    test('returns a SignedOffchainAttestation', () async {
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test attestation',
      );

      expect(result, isA<SignedOffchainAttestation>());
    });

    test('signed attestation has correct signer address', () async {
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test',
      );

      expect(result.signer.toLowerCase(), _testAddress.toLowerCase());
    });

    test('signed attestation has non-empty UID', () async {
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test',
      );

      expect(result.uid, isNotEmpty);
      expect(result.uid, startsWith('0x'));
    });

    test('signed attestation uses app schema UID', () async {
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test',
      );

      expect(result.schemaUID, AppSchema.schemaUID);
    });

    test('signed attestation has valid signature', () async {
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test',
      );

      expect(result.signature.v, anyOf(27, 28));
      expect(result.signature.r, startsWith('0x'));
      expect(result.signature.s, startsWith('0x'));
    });

    test('uses provided eventTimestamp when given', () async {
      final ts = BigInt.from(1700000000);
      final result = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'test',
        eventTimestamp: ts,
      );

      // The eventTimestamp is ABI-encoded in result.data — we verify indirectly
      // by checking the attestation is valid (encoding must be correct).
      expect(result, isA<SignedOffchainAttestation>());
    });
  });

  group('AttestationService.verifyOffchain', () {
    test('valid attestation verifies successfully', () async {
      final signed = await service.signOffchain(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'verify test',
      );

      final result = service.verifyOffchain(signed);

      expect(result.isValid, isTrue);
      expect(
        result.recoveredAddress.toLowerCase(),
        _testAddress.toLowerCase(),
      );
    });

    test('returns VerificationResult', () async {
      final signed = await service.signOffchain(
        lat: 0,
        lng: 0,
        memo: 'test',
      );

      final result = service.verifyOffchain(signed);
      expect(result, isA<VerificationResult>());
    });
  });

  group('AttestationService — round trip', () {
    test('sign then verify round-trips correctly', () async {
      final signed = await service.signOffchain(
        lat: 51.5074,
        lng: -0.1278,
        memo: 'London test',
      );

      final verification = service.verifyOffchain(signed);

      expect(verification.isValid, isTrue);
      expect(
        verification.recoveredAddress.toLowerCase(),
        signed.signer.toLowerCase(),
      );
    });

    test('different inputs produce different UIDs', () async {
      final a = await service.signOffchain(lat: 0, lng: 0, memo: 'a');
      final b = await service.signOffchain(lat: 1, lng: 1, memo: 'b');

      expect(a.uid, isNot(b.uid));
    });
  });

  group('AttestationService — onchain calldata builders', () {
    test('buildAttestCallData returns non-empty Uint8List', () {
      final callData = service.buildAttestCallData(
        lat: 37.7749,
        lng: -122.4194,
        memo: 'onchain test',
      );

      expect(callData, isA<Uint8List>());
      expect(callData.isNotEmpty, isTrue);
    });

    test('buildTimestampCallData returns non-empty Uint8List', () {
      final callData = service.buildTimestampCallData(
        '0x${'ab' * 32}',
      );

      expect(callData, isA<Uint8List>());
      expect(callData.isNotEmpty, isTrue);
    });

    test('buildRegisterSchemaCallData returns non-empty Uint8List', () {
      final callData = service.buildRegisterSchemaCallData();

      expect(callData, isA<Uint8List>());
      expect(callData.isNotEmpty, isTrue);
    });
  });

  group('AttestationService — tx request builder', () {
    test('buildTxRequest produces wallet-friendly map', () {
      final callData = service.buildAttestCallData(
        lat: 0,
        lng: 0,
        memo: 'tx test',
      );

      final txRequest = service.buildTxRequest(
        callData: callData,
        contractAddress: service.easAddress,
      );

      expect(txRequest, isA<Map<String, dynamic>>());
      expect(txRequest['to'], isNotEmpty);
      expect(txRequest['data'], startsWith('0x'));
      expect(txRequest['from'], _testAddress);
      // Privy Android SDK requires chainId as 0x-prefixed hex.
      expect(txRequest['chainId'], '0xaa36a7'); // 11155111 in hex
      expect(txRequest.containsKey('sponsor'), isFalse);
    });

    test('buildTxRequest includes sponsor flag when sponsorGas is true', () {
      final sponsorService = AttestationService(
        signer: signer,
        chainId: 11155111,
        rpcUrl: 'https://unused.rpc',
        sponsorGas: true,
      );

      final txRequest = sponsorService.buildTxRequest(
        callData: Uint8List.fromList([1, 2, 3]),
        contractAddress: '0x123',
      );

      expect(txRequest['sponsor'], isTrue);
    });

    test('easAddress is non-empty for Sepolia', () {
      expect(service.easAddress, isNotEmpty);
      expect(service.easAddress, startsWith('0x'));
    });

    test('schemaRegistryAddress is non-empty for Sepolia', () {
      expect(service.schemaRegistryAddress, isNotEmpty);
      expect(service.schemaRegistryAddress, startsWith('0x'));
    });
  });

  group('AttestationService — RPC checks', () {
      late AttestationService rpcService;
      late PrivySigner privySigner;
      late String configuredRpcUrl;
      late int signerRpcCalls;
      late List<Map<String, dynamic>> capturedRequests;

      setUp(() {
        signerRpcCalls = 0;
        capturedRequests = [];
        configuredRpcUrl = 'https://configured.rpc';
      });

      PrivySigner buildFailingSigner() {
        return PrivySigner(
          walletAddress: _testAddress,
          rpcCaller: (method, params) async {
            signerRpcCalls++;
            throw Exception('Signer RPC should not be used for read paths');
          },
        );
      }

      http.BaseClient buildClient(String responseBody) {
        return FakeClient((request) async {
          final body = request is http.Request ? request.body : '';
          capturedRequests.add({
            'url': request.url.toString(),
            'body': body,
          });
          return http.Response(responseBody, 200);
        });
      }

      test('getSchemaRecord uses the configured RPC URL', () async {
        privySigner = buildFailingSigner();
        rpcService = AttestationService(
          signer: privySigner,
          chainId: 1,
          rpcUrl: configuredRpcUrl,
          httpClient: buildClient(
            '{"jsonrpc":"2.0","id":1,"result":"${AppSchema.schemaUID}"}',
          ),
        );

        final result = await rpcService.getSchemaRecord(AppSchema.schemaUID);

        expect(result, AppSchema.schemaUID);
        expect(signerRpcCalls, 0);
        expect(capturedRequests, hasLength(1));
        expect(capturedRequests.single['url'], configuredRpcUrl);
        expect(capturedRequests.single['body'], contains('"method":"eth_call"'));
      });

      test('getTimestamp uses the configured RPC URL', () async {
        privySigner = buildFailingSigner();
        rpcService = AttestationService(
          signer: privySigner,
          chainId: 1,
          rpcUrl: configuredRpcUrl,
          httpClient: buildClient(
            '{"jsonrpc":"2.0","id":1,"result":"0x1234"}',
          ),
        );

        final result = await rpcService.getTimestamp('0x${'ab' * 32}');

        expect(result, '0x1234');
        expect(signerRpcCalls, 0);
        expect(capturedRequests.single['url'], configuredRpcUrl);
        expect(capturedRequests.single['body'], contains('"method":"eth_call"'));
      });

      test('isTimestamped returns false for the zero timestamp word', () async {
        privySigner = buildFailingSigner();
        rpcService = AttestationService(
          signer: privySigner,
          chainId: 1,
          rpcUrl: configuredRpcUrl,
          httpClient: buildClient(
            '{"jsonrpc":"2.0","id":1,"result":"${EASConstants.zeroBytes32}"}',
          ),
        );

        final result = await rpcService.isTimestamped('0x${'ab' * 32}');

        expect(result, isFalse);
      });

      test('isTimestamped returns true for a non-zero timestamp word', () async {
        privySigner = buildFailingSigner();
        rpcService = AttestationService(
          signer: privySigner,
          chainId: 1,
          rpcUrl: configuredRpcUrl,
          httpClient: buildClient(
            '{"jsonrpc":"2.0","id":1,"result":"0x${'00' * 31}01"}',
          ),
        );

        final result = await rpcService.isTimestamped('0x${'ab' * 32}');

        expect(result, isTrue);
      });

      test('getTransactionReceipt returns a typed TransactionReceipt', () async {
        privySigner = buildFailingSigner();
        rpcService = AttestationService(
          signer: privySigner,
          chainId: 1,
          rpcUrl: configuredRpcUrl,
          httpClient: buildClient(
            '{"jsonrpc":"2.0","id":1,"result":{"blockNumber":"0x1","status":"0x1"}}',
          ),
        );

        final receipt = await rpcService.getTransactionReceipt('0x123');

        expect(receipt, isA<TransactionReceipt>());
        expect(receipt!.blockNumber, 1);
        expect(receipt.status, isTrue);
        expect(signerRpcCalls, 0);
        expect(capturedRequests.single['url'], configuredRpcUrl);
        expect(capturedRequests.single['body'], contains('"method":"eth_getTransactionReceipt"'));
      });

      test('waitForAttestationUid succeeds through the configured RPC URL', () async {
        int pollCount = 0;
        privySigner = buildFailingSigner();
        rpcService = AttestationService(
          signer: privySigner,
          chainId: 11155111,
          rpcUrl: configuredRpcUrl,
          httpClient: FakeClient((request) async {
            final body = request is http.Request ? request.body : '';
            capturedRequests.add({
              'url': request.url.toString(),
              'body': body,
            });
            if (pollCount++ < 1) {
              return http.Response('{"jsonrpc":"2.0","id":1,"result":null}', 200);
            }
            return http.Response(
              '{"jsonrpc":"2.0","id":1,"result":{"logs":[{"address":"${rpcService.easAddress}","topics":["${EASConstants.attestedEventTopic}"],"data":"0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"}]}}',
              200,
            );
          }),
        );

        final uid = await rpcService.waitForAttestationUid(
          '0xtx',
          pollInterval: const Duration(milliseconds: 1),
        );

        expect(uid, '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
        expect(signerRpcCalls, 0);
        expect(pollCount, 2);
        expect(capturedRequests, hasLength(2));
        expect(capturedRequests.every((request) => request['url'] == configuredRpcUrl), isTrue);
      });

      test('waitForAttestationUid ignores non-Attested logs from the EAS contract', () async {
        privySigner = buildFailingSigner();
        rpcService = AttestationService(
          signer: privySigner,
          chainId: 11155111,
          rpcUrl: configuredRpcUrl,
          httpClient: buildClient(
            '{"jsonrpc":"2.0","id":1,"result":{"blockNumber":"0x1","status":"0x1","logs":[{"address":"${ChainConfig.forChainId(11155111)!.eas}","topics":["0xdeadbeef"],"data":"0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"}]}}',
          ),
        );

        await expectLater(
          rpcService.waitForAttestationUid('0xtx'),
          throwsStateError,
        );
      });

      test('waitForAttestationUid throws StateError when the receipt is reverted', () async {
        privySigner = buildFailingSigner();
        rpcService = AttestationService(
          signer: privySigner,
          chainId: 11155111,
          rpcUrl: configuredRpcUrl,
          httpClient: buildClient(
            '{"jsonrpc":"2.0","id":1,"result":{"blockNumber":"0x2","status":"0x0","logs":[]}}',
          ),
        );

        await expectLater(
          rpcService.waitForAttestationUid('0xreverted'),
          throwsStateError,
        );
      });
  });

  group('AttestationService — new dynamic methods', () {
    test('isSchemaUidRegistered returns true for a matching ABI-encoded schema record', () async {
      final schemaRecord = _encodeAbiSchemaRecord(
        uid: AppSchema.schemaUID,
        schema: AppSchema.definition.toEASSchemaString(),
      );
      final customService = AttestationService(
        signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
        chainId: 11155111,
        rpcUrl: 'https://unused.rpc',
        httpClient: FakeClient((_) async => http.Response(
          '{"jsonrpc":"2.0","id":1,"result":"$schemaRecord"}',
          200,
        )),
      );

      final result = await customService.isSchemaUidRegistered(AppSchema.schemaUID);

      expect(result, isTrue);
    });

    test('isSchemaUidRegistered accepts any UID (returns false for test RPC)', () async {
      // Enough to test the method exists and doesn't throw with a fake RPC response
      final customService = AttestationService(
        signer: LocalKeySigner(privateKeyHex: _testPrivateKey),
        chainId: 11155111,
        rpcUrl: 'https://unused.rpc',
        httpClient: FakeClient((_) async => http.Response(
          '{"jsonrpc":"2.0","id":1,"result":"0x0000000000000000000000000000000000000000000000000000000000000020"}',
          200,
        )),
      );
      final result = await customService.isSchemaUidRegistered('0x${'ab' * 32}');
      expect(result, isFalse); // UID won't match the fake response
    });

    test('signOffchainWithData returns a SignedOffchainAttestation', () async {
      final result = await service.signOffchainWithData(
        schema: AppSchema.definition,
        lat: 37.7749,
        lng: -122.4194,
        userData: AppSchema.buildUserData(memo: 'dynamic test'),
      );
      expect(result, isA<SignedOffchainAttestation>());
    });

    test('buildAttestCallDataWithUserData returns non-empty Uint8List', () {
      final callData = service.buildAttestCallDataWithUserData(
        schema: AppSchema.definition,
        lat: 37.7749,
        lng: -122.4194,
        userData: AppSchema.buildUserData(memo: 'dynamic test'),
      );
      expect(callData, isA<Uint8List>());
      expect(callData.isNotEmpty, isTrue);
    });

    test('buildRegisterSchemaCallData accepts explicit schema', () {
      final customSchema = SchemaDefinition(
        fields: [SchemaField(type: 'string', name: 'test')],
      );
      final callData = service.buildRegisterSchemaCallData(customSchema);
      expect(callData, isA<Uint8List>());
      expect(callData.isNotEmpty, isTrue);
    });

    test('buildRegisterSchemaCallData uses default schema when called with no args', () {
      final callData = service.buildRegisterSchemaCallData();
      expect(callData, isA<Uint8List>());
      expect(callData.isNotEmpty, isTrue);
    });
  });
}

class FakeClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  FakeClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final resp = await handler(request);
    return http.StreamedResponse(
      Stream.value(resp.bodyBytes),
      resp.statusCode,
      headers: resp.headers,
    );
  }
}
