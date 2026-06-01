import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/services/reown_service.dart';

void main() {
  testWidgets('reports unavailable when REOWN_PROJECT_ID is missing', (
    tester,
  ) async {
    final service = ReownService();

    expect(service.isAvailable, isFalse);
    expect(service.isInitialized, isFalse);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));

    await service.initialize(context);

    expect(service.isAvailable, isFalse);
    expect(service.isInitialized, isFalse);
  });

  test('connectAndGetAddress returns null when unavailable', () async {
    final service = ReownService();

    expect(await service.connectAndGetAddress(), isNull);
  });

  testWidgets('public wallet operations throw StateError when unavailable', (
    tester,
  ) async {
    final service = ReownService();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));

    await expectLater(
      service.personalSign(context, 'message'),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'ReownService unavailable',
      )),
    );

    await expectLater(
      service.signTypedData(context, const <String, dynamic>{}),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'ReownService unavailable',
      )),
    );

    await expectLater(
      service.sendTransaction(context, const <String, dynamic>{}),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'ReownService unavailable',
      )),
    );
  });

  test('connected session chain takes precedence over selected chain', () {
    expect(
      ReownService.resolveRequestChainId(
        sessionChainId: 'eip155:1',
        selectedChainId: 'eip155:11155111',
      ),
      'eip155:1',
    );

    expect(
      ReownService.resolveRequestChainId(
        sessionChainId: null,
        selectedChainId: 'eip155:11155111',
      ),
      'eip155:11155111',
    );
  });

  test('uses the Android custom scheme redirect', () {
    expect(ReownService.appScheme, 'locationprotocol');
  });

  testWidgets('signTypedData sends the expected wallet request shape', (
    tester,
  ) async {
    final modal = FakeReownModalAdapter(
      address: '0x1234567890123456789012345678901234567890',
      sessionChainId: 'eip155:1',
      selectedChainId: 'eip155:1',
      requestResult: '0x${'aa' * 32}${'bb' * 32}1b',
    );
    final service = ReownService(modalAdapter: modal, projectIdOverride: 'test');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));

    final typedData = <String, dynamic>{
      'domain': {'name': 'EAS'},
      'types': {'Attest': <Map<String, dynamic>>[]},
      'primaryType': 'Attest',
      'message': {'version': 1},
    };

    final signature = await service.signTypedData(
      context,
      typedData,
      targetChainId: 'eip155:11155111',
    );

    expect(signature, isA<EIP712Signature>());
    expect(modal.selectedChains, ['eip155:11155111']);
    expect(modal.requestCalls, hasLength(1));
    expect(modal.requestCalls.single.method, 'eth_signTypedData_v4');
    expect(modal.requestCalls.single.chainId, 'eip155:11155111');
    expect(modal.requestCalls.single.params, [
      '0x1234567890123456789012345678901234567890',
      typedData,
    ]);
  });

  testWidgets('sendTransaction forwards the tx request unchanged', (
    tester,
  ) async {
    final modal = FakeReownModalAdapter(
      address: '0x1234567890123456789012345678901234567890',
      sessionChainId: 'eip155:11155111',
      selectedChainId: 'eip155:11155111',
      requestResult: '0xtxhash',
    );
    final service = ReownService(modalAdapter: modal, projectIdOverride: 'test');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));

    final txRequest = <String, dynamic>{
      'to': '0xabc',
      'data': '0x1234',
      'from': '0x1234567890123456789012345678901234567890',
      'chainId': '0xaa36a7',
      'sponsor': true,
    };

    final txHash = await service.sendTransaction(
      context,
      txRequest,
      targetChainId: 'eip155:11155111',
    );

    expect(txHash, '0xtxhash');
    expect(modal.requestCalls, hasLength(1));
    expect(modal.requestCalls.single.method, 'eth_sendTransaction');
    expect(modal.requestCalls.single.chainId, 'eip155:11155111');
    expect(modal.requestCalls.single.params, [txRequest]);
  });
}

class FakeReownModalAdapter implements ReownModalAdapter {
  FakeReownModalAdapter({
    required this.address,
    required this.sessionChainId,
    required this.selectedChainId,
    required this.requestResult,
    this.connected = true,
  });

  @override
  final String address;

  bool connected;

  @override
  bool get isConnected => connected;

  final String requestResult;

  @override
  String? selectedChainId;

  @override
  String? sessionChainId;

  @override
  String get sessionTopic => 'topic-1';

  final List<String> selectedChains = [];
  final List<ReownRequestCall> requestCalls = [];

  @override
  Future<void> openModalView() async {}

  @override
  Future<Object?> request({
    required String topic,
    required String chainId,
    required String method,
    required List<dynamic> params,
  }) async {
    requestCalls.add(
      ReownRequestCall(
        topic: topic,
        chainId: chainId,
        method: method,
        params: params,
      ),
    );
    return requestResult;
  }

  @override
  Future<void> selectChain(String chainId) async {
    selectedChains.add(chainId);
    selectedChainId = chainId;
  }
}

class ReownRequestCall {
  ReownRequestCall({
    required this.topic,
    required this.chainId,
    required this.method,
    required this.params,
  });

  final String topic;
  final String chainId;
  final String method;
  final List<dynamic> params;
}
