import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:privy_flutter/src/modules/embedded_ethereum_wallet_provider/embedded_ethereum_wallet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location_protocol_flutter_app/privy/privy_auth_provider.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';
import 'package:location_protocol_flutter_app/services/reown_service.dart';
import 'package:location_protocol_flutter_app/settings/settings_service.dart';

class MockReownService extends Mock implements ReownService {}
class MockEmbeddedWalletProvider extends Mock
    implements EmbeddedEthereumWalletProvider {}
class MockEmbeddedWallet extends Mock implements EmbeddedEthereumWallet {}
class FakeBuildContext extends Fake implements BuildContext {}

class FakePrivyAuthState extends PrivyAuthState {
  FakePrivyAuthState({
    required bool authenticated,
    EmbeddedEthereumWallet? wallet,
    String? walletAddress,
  })  : _authenticated = authenticated,
        _wallet = wallet,
        _walletAddress = walletAddress;

  bool _authenticated;
  EmbeddedEthereumWallet? _wallet;
  String? _walletAddress;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  EmbeddedEthereumWallet? get wallet => _wallet;

  @override
  String? get walletAddress => _walletAddress;

  @override
  Future<void> logout() async {
    _authenticated = false;
    _wallet = null;
    _walletAddress = null;
    notifyListeners();
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      EthereumRpcRequest(method: 'eth_sendTransaction', params: const []),
    );
    registerFallbackValue(FakeBuildContext());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SettingsService> createSettingsService() => SettingsService.create();

  Future<AppWalletProvider> createProvider({
    FakePrivyAuthState? privyAuth,
    ReownService? reownService,
    SettingsService? settingsService,
  }) async {
    final provider = AppWalletProvider(
      privyAuth: privyAuth,
      reownService: reownService,
      settingsService: settingsService ?? await createSettingsService(),
    );
    await provider.ready;
    return provider;
  }

  MockEmbeddedWallet buildPrivyWallet(String txHash) {
    final walletProvider = MockEmbeddedWalletProvider();
    when(() => walletProvider.request(any())).thenAnswer(
      (_) async => Success(
        EthereumRpcResponse(method: 'eth_sendTransaction', data: txHash),
      ),
    );

    final wallet = MockEmbeddedWallet();
    when(() => wallet.provider).thenReturn(walletProvider);
    return wallet;
  }

  test('last active mode is persisted and restored', () async {
    final settings = await createSettingsService();
    final provider = await createProvider(settingsService: settings);

    await provider.setExternalAddress('0x1234567890123456789012345678901234567890');

    expect(settings.lastActiveWalletMode, 'external');
    expect(provider.connectionType, ConnectionType.external);

    final restored = await createProvider(settingsService: settings);
    expect(restored.lastActiveWalletMode, 'external');
    expect(restored.connectionType, ConnectionType.none);
  });

  test('private key remains in memory only', () async {
    final settings = await createSettingsService();
    final provider = await createProvider(settingsService: settings);

    await provider.setPrivateKey(
      '0000000000000000000000000000000000000000000000000000000000000001',
    );

    expect(provider.connectionType, ConnectionType.privateKey);
    expect(settings.lastActiveWalletMode, isNull);

    final restored = await createProvider(settingsService: settings);
    expect(restored.connectionType, ConnectionType.none);
  });

  test('precedence follows last active mode when both connections exist',
      () async {
    final settings = await createSettingsService();
    final privyWallet = buildPrivyWallet('0xprivy-hash');
    final privyAuth = FakePrivyAuthState(
      authenticated: true,
      wallet: privyWallet,
      walletAddress: '0xprivy-address',
    );
    final provider = await createProvider(
      privyAuth: privyAuth,
      settingsService: settings,
    );

    await provider.setExternalAddress('0x1234567890123456789012345678901234567890');
    expect(provider.connectionType, ConnectionType.external);

    await settings.setLastActiveWalletMode('privy');
    expect(provider.connectionType, ConnectionType.privy);
  });

  test('fallback precedence prefers privy, then external, then none', () async {
    final settings = await createSettingsService();
    final privyWallet = buildPrivyWallet('0xprivy-hash');
    final privyAuth = FakePrivyAuthState(
      authenticated: true,
      wallet: privyWallet,
      walletAddress: '0xprivy-address',
    );

    final invalidModeProvider = await createProvider(
      privyAuth: privyAuth,
      settingsService: settings,
    );
    await settings.setLastActiveWalletMode('invalid');
    expect(invalidModeProvider.connectionType, ConnectionType.privy);

    final externalOnlySettings = await createSettingsService();
    final externalOnlyProvider = await createProvider(
      settingsService: externalOnlySettings,
    );
    await externalOnlyProvider.setExternalAddress(
      '0x1234567890123456789012345678901234567890',
    );
    expect(externalOnlyProvider.connectionType, ConnectionType.external);

    final noneProvider = await createProvider(
      settingsService: await createSettingsService(),
    );
    expect(noneProvider.connectionType, ConnectionType.none);
  });

  testWidgets('sendTransaction returns a hash for external wallets', (
      tester) async {
    final settings = await createSettingsService();
    final reownService = MockReownService();
    when(
      () => reownService.sendTransaction(
        any(),
        any(),
        targetChainId: any(named: 'targetChainId'),
      ),
    ).thenAnswer((_) async => '0xexternal-hash');

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));

    final provider = await createProvider(
      reownService: reownService,
      settingsService: settings,
    );
    await provider.setExternalAddress('0x1234567890123456789012345678901234567890');

    final hash = await provider.sendTransaction(
      const {
        'to': '0xabc',
        'chainId': '0xaa36a7',
        'sponsor': true,
      },
      context: context,
    );

    expect(hash, '0xexternal-hash');
    verify(
      () => reownService.sendTransaction(
        any(),
        {
          'to': '0xabc',
          'chainId': '0xaa36a7',
          'sponsor': true,
        },
        targetChainId: 'eip155:11155111',
      ),
    ).called(1);
  });

  test('sendTransaction returns a hash for privy wallets', () async {
    final settings = await createSettingsService();
    final provider = await createProvider(
      privyAuth: FakePrivyAuthState(
        authenticated: true,
        wallet: buildPrivyWallet('0xprivy-hash'),
        walletAddress: '0xprivy-address',
      ),
      settingsService: settings,
    );

    await settings.setLastActiveWalletMode('privy');

    final hash = await provider.sendTransaction(const {'to': '0xabc'});

    expect(hash, '0xprivy-hash');
  });

  test('sendTransaction throws when transactions are unavailable', () async {
    final provider = await createProvider(
      settingsService: await createSettingsService(),
    );

    expect(
      () => provider.sendTransaction(const {'to': '0xabc'}),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Transactions unavailable for current connection type',
        ),
      ),
    );
  });
}
