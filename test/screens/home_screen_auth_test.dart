import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';
import 'package:location_protocol_flutter_app/screens/home_screen.dart';
import 'package:location_protocol_flutter_app/services/reown_service.dart';
import 'package:location_protocol_flutter_app/services/runtime_network_config.dart';
import 'package:location_protocol_flutter_app/settings/settings_service.dart';
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
  ReownService? reownService,
}) async {
  final provider = AppWalletProvider(
    privyAuth: privyAuth,
    reownService: reownService,
    settingsService: await SettingsService.create(),
  );
  await provider.ready;
  return provider;
}

Widget _buildApp(AppWalletProvider walletProvider) {
  return ChangeNotifierProvider<AppWalletProvider>.value(
    value: walletProvider,
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

  testWidgets('disconnected state shows the login CTA', (tester) async {
    final walletProvider = await _buildWalletProvider(
      privyAuth: FakePrivyAuthState(ready: true, authenticated: false),
    );

    await tester.pumpWidget(_buildApp(walletProvider));
    await tester.pumpAndSettle();

    expect(find.text('Connect Wallet'), findsOneWidget);
    expect(find.text('Sign Offchain Attestation'), findsOneWidget);
    expect(find.text('Attest Onchain'), findsNothing);
  });

  testWidgets('external wallet state exposes the offchain path and onchain actions',
      (tester) async {
    final walletProvider = await _buildWalletProvider(
      privyAuth: FakePrivyAuthState(ready: true, authenticated: false),
      reownService: ReownService(),
    );
    await walletProvider.setExternalAddress(
      '0x1234567890123456789012345678901234567890',
    );

    await tester.pumpWidget(_buildApp(walletProvider));
    await tester.pumpAndSettle();

    expect(find.text('Connect Wallet'), findsNothing);
    expect(find.text('Sign Offchain Attestation'), findsOneWidget);
    expect(find.text('Attest Onchain'), findsOneWidget);
    expect(find.text('Register Schema'), findsOneWidget);
    expect(find.text('Timestamp Offchain UID'), findsOneWidget);
  });

  testWidgets('private key state keeps onchain actions hidden', (tester) async {
    final walletProvider = await _buildWalletProvider(
      privyAuth: FakePrivyAuthState(ready: true, authenticated: false),
    );
    await walletProvider.setPrivateKey(
      '0000000000000000000000000000000000000000000000000000000000000001',
    );

    await tester.pumpWidget(_buildApp(walletProvider));
    await tester.pumpAndSettle();

    expect(find.text('Connect Wallet'), findsNothing);
    expect(find.text('Sign Offchain Attestation'), findsOneWidget);
    expect(find.text('Attest Onchain'), findsNothing);
    expect(find.text('Register Schema'), findsNothing);
    expect(find.text('Timestamp Offchain UID'), findsNothing);
  });
}
