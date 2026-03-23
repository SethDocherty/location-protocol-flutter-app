import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';
import 'package:location_protocol_flutter_app/settings/settings_service.dart';
import 'package:location_protocol_flutter_app/widgets/private_key_import_dialog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockSettingsService extends Mock implements SettingsService {}

Widget _buildHost(AppWalletProvider walletProvider, SettingsService settings) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppWalletProvider>.value(value: walletProvider),
      Provider<SettingsService>.value(value: settings),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                final key = await showPrivateKeyImportDialog(context);
                if (key != null && key.isNotEmpty) {
                  await context.read<AppWalletProvider>().setPrivateKey(key);
                }
              },
              child: const Text('Open import dialog'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue('external');
  });

  testWidgets('returns a key to the caller without touching settings',
      (tester) async {
    final walletProvider = AppWalletProvider();
    final settings = MockSettingsService();

    await tester.pumpWidget(_buildHost(walletProvider, settings));
    await tester.tap(find.text('Open import dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField),
        '0x0000000000000000000000000000000000000000000000000000000000000001');
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(walletProvider.connectionType, ConnectionType.privateKey);
    verifyNever(() => settings.setLastActiveWalletMode(any()));
  });

  testWidgets('empty submission and cancel keep provider state unchanged',
      (tester) async {
    final walletProvider = AppWalletProvider();
    final settings = MockSettingsService();

    await tester.pumpWidget(_buildHost(walletProvider, settings));
    await tester.tap(find.text('Open import dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(walletProvider.connectionType, ConnectionType.none);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(walletProvider.connectionType, ConnectionType.none);
    verifyNever(() => settings.setLastActiveWalletMode(any()));
  });
}
