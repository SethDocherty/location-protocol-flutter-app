import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
