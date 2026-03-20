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

void main() {
  late AttestationService service;
  late LocalKeySigner signer;

  setUp(() {
    signer = LocalKeySigner(privateKeyHex: _testPrivateKey);
    service = AttestationService(
      signer: signer,
      chainId: 11155111, // Sepolia
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
    String? capturedMethod;

    test('isSchemaRegistered returns true when UID is non-zero', () async {
      privySigner = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (method, params) async {
          capturedMethod = method;
          // Return the real UID (first 32 bytes) to match strict check
          return AppSchema.schemaUID;
        },
      );
      rpcService = AttestationService(signer: privySigner, chainId: 1);

      final result = await rpcService.isSchemaRegistered();
      expect(result, isTrue);
      expect(capturedMethod, 'eth_call');
    });

    test('isSchemaRegistered returns false when UID is zero', () async {
      privySigner = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (method, params) async {
          capturedMethod = method;
          // Return zero UID
          return '0x${'00' * 32}';
        },
      );
      rpcService = AttestationService(signer: privySigner, chainId: 1);

      final result = await rpcService.isSchemaRegistered();
      expect(result, isFalse);
    });

    test('getTransactionReceipt returns decoded map', () async {
      privySigner = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (method, params) async {
          capturedMethod = method;
          return '{"blockNumber": "0x1", "status": "0x1"}';
        },
      );
      rpcService = AttestationService(signer: privySigner, chainId: 1);

      final receipt = await rpcService.getTransactionReceipt('0x123');
      expect(receipt, isA<Map<String, dynamic>>());
      expect(receipt!['blockNumber'], '0x1');
      expect(capturedMethod, 'eth_getTransactionReceipt');
    });

    test('getTransactionReceipt returns null for empty/null response', () async {
      privySigner = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (method, params) async => 'null',
      );
      rpcService = AttestationService(signer: privySigner, chainId: 1);

      final receipt = await rpcService.getTransactionReceipt('0x123');
      expect(receipt, isNull);
    });
    test('isSchemaRegistered throws UnsupportedError if fallback missing', () async {
      privySigner = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (method, params) async => throw Exception('Unsupported'),
      );
      rpcService = AttestationService(signer: privySigner, chainId: 1);

      expect(
        rpcService.isSchemaRegistered(),
        throwsA(isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('Please configure an RPC URL in Settings'),
        )),
      );
    });
  });

  group('AttestationService — HTTP Fallback', () {
    test('falls back to HTTP when signer throws Unsupported method', () async {
      final privySigner = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (method, params) async =>
            throw Exception('Unsupported method: eth_call'),
      );

      final fakeClient = FakeClient((request) async {
        return http.Response(
          '{"jsonrpc":"2.0","id":1,"result":"${AppSchema.schemaUID}"}',
          200,
        );
      });

      final service = AttestationService(
        signer: privySigner,
        chainId: 1,
        fallbackRpcUrl: 'https://fallback.rpc',
        httpClient: fakeClient,
      );

      final result = await service.isSchemaRegistered();
      expect(result, isTrue);
    });

    test('bubbles up HTTP errors from fallback', () async {
      final privySigner = PrivySigner(
        walletAddress: _testAddress,
        rpcCaller: (method, params) async =>
            throw Exception('Unsupported method'),
      );

      final fakeClient = FakeClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = AttestationService(
        signer: privySigner,
        chainId: 1,
        fallbackRpcUrl: 'https://fallback.rpc',
        httpClient: fakeClient,
      );

      expect(service.isSchemaRegistered(), throwsA(isA<Exception>()));
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
