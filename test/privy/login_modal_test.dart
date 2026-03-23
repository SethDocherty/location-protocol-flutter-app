import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';
import 'package:location_protocol_flutter_app/privy/login_modal.dart';
import 'package:location_protocol_flutter_app/privy/privy_auth_config.dart';
import 'package:location_protocol_flutter_app/privy/privy_auth_provider.dart';
import 'package:location_protocol_flutter_app/services/reown_service.dart';
import 'package:provider/provider.dart';

Future<void> _openLoginModal(WidgetTester tester) async {
  await tester.tap(find.text('Open login modal'));
  await tester.pumpAndSettle();
}

Widget _buildLoginHost({ReownService? reownService}) {
  final appWalletProvider = AppWalletProvider();
  return PrivyAuthProvider(
    config: const PrivyAuthConfig(
      appId: 'test-app-id',
      clientId: 'test-client-id',
      oauthAppUrlScheme: 'test-scheme',
    ),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<AppWalletProvider>.value(value: appWalletProvider),
        Provider<ReownService>.value(value: reownService ?? ReownService()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showPrivyLoginModal(context),
                child: const Text('Open login modal'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('selector shows external connect and private key import options',
      (tester) async {
    await tester.pumpWidget(_buildLoginHost());

    await _openLoginModal(tester);

    expect(find.text('Import Private Key'), findsOneWidget);
    expect(find.text('Connect External Wallet'), findsOneWidget);
    expect(find.text('Connect Wallet'), findsNothing);
  });

  testWidgets('external connect is disabled when Reown is unavailable',
      (tester) async {
    await tester.pumpWidget(_buildLoginHost());

    await _openLoginModal(tester);

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('connect-external-wallet')),
    );

    expect(button.onPressed, isNull);
    expect(
      find.textContaining('REOWN_PROJECT_ID'),
      findsOneWidget,
    );
  });
}
