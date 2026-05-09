import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';
import 'package:location_protocol_flutter_app/screens/home_screen.dart';
import 'package:location_protocol_flutter_app/services/runtime_network_config.dart';
import 'package:location_protocol_flutter_app/settings/settings_service.dart';
import 'package:location_protocol_flutter_app/providers/schema_provider.dart';
import 'package:location_protocol_flutter_app/privy/privy_auth_provider.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePrivyAuthState extends PrivyAuthState {
  FakePrivyAuthState({
    required bool ready,
    required bool authenticated,
    EmbeddedEthereumWallet? wallet,
    String? walletAddress,
  })  : _ready = ready,
        _authenticated = authenticated,
        _wallet = wallet,
        _walletAddress = walletAddress;

  final bool _ready;
  bool _authenticated;
  final EmbeddedEthereumWallet? _wallet;
  final String? _walletAddress;

  @override
  bool get isReady => _ready;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  EmbeddedEthereumWallet? get wallet => _wallet;

  @override
  String? get walletAddress => _walletAddress;

  @override
  Future<void> logout() async {
    _authenticated = false;
    notifyListeners();
  }
}

Future<AppWalletProvider> _buildWalletProvider({
  required PrivyAuthState privyAuth,
}) async {
  final provider = AppWalletProvider(
    privyAuth: privyAuth,
    settingsService: await SettingsService.create(),
  );
  await provider.ready;
  return provider;
}

Widget _buildApp(AppWalletProvider walletProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppWalletProvider>.value(value: walletProvider),
      ChangeNotifierProvider<SchemaProvider>(create: (_) => SchemaProvider()),
    ],
    child: MaterialApp(
      home: const HomeScreen(
        runtimeNetworkConfig: RuntimeNetworkConfig(
          selectedChainId: 11155111,
          rpcUrl: 'https://rpc.example.com',
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('copy button exists and shows snackbar when clicked', (tester) async {
    final walletProvider = await _buildWalletProvider(
      privyAuth: FakePrivyAuthState(ready: true, authenticated: false),
    );
    // Simulate an external wallet connected
    await walletProvider.setExternalAddress('0x1234567890123456789012345678901234567890');

    await tester.pumpWidget(_buildApp(walletProvider));
    await tester.pumpAndSettle();

    // Find the copy button by tooltip
    final copyButton = find.byTooltip('Copy Address');
    expect(copyButton, findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);

    // Click the button
    await tester.tap(copyButton);
    await tester.pump();

    // Verify Snackbar appears
    expect(find.text('Address copied'), findsOneWidget);

    // Verify Clipboard was called (basic check by ensuring no error occurred)
    // In a real environment we could verify the clipboard content, 
    // but in widget tests we'd need to mock the clipboard service if we wanted deeper verification.
  });
}
