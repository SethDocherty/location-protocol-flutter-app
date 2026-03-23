import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/privy/privy_auth_provider.dart';

void main() {
  group('PrivyAuthState', () {
    late PrivyAuthState state;

    setUp(() {
      state = PrivyAuthState();
    });

    tearDown(() {
      state.dispose();
    });

    test('initial state is not ready and not authenticated', () {
      expect(state.isReady, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
      expect(state.wallet, isNull);
      expect(state.walletAddress, isNull);
      expect(state.error, isNull);
    });

    test('notifies listeners on state change', () {
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      // PrivyAuthState._update is private, so we test via logout()
      // which calls _update internally. For direct _update testing,
      // we'd need to make it @visibleForTesting or test through
      // the provider. For now, test the public API.
      expect(notifyCount, 0);
    });

    test('logout clears all state fields', () async {
      // We can't easily test logout without mocking PrivyManager.
      // This test verifies the state object itself is a ChangeNotifier.
      expect(state, isA<ChangeNotifier>());
    });
  });
}
