import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'privy/privy_module.dart';
import 'screens/home_screen.dart';
import 'services/runtime_network_config.dart';
import 'services/reown_service.dart';
import 'settings/settings_service.dart';
import 'providers/app_wallet_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const LocationProtocolApp());
}

class LocationProtocolApp extends StatefulWidget {
  const LocationProtocolApp({super.key});

  @override
  State<LocationProtocolApp> createState() => _LocationProtocolAppState();
}

class _LocationProtocolAppState extends State<LocationProtocolApp> {
  SettingsService? _settingsService;
  RuntimeNetworkConfig? _runtimeNetworkConfig;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settingsService = await SettingsService.create();
    if (!mounted) return;
    setState(() {
      _settingsService = settingsService;
      _runtimeNetworkConfig = RuntimeNetworkConfig.fromSettings(settingsService);
    });
  }

  Future<void> _refreshRuntimeNetworkConfig() async {
    final settingsService = _settingsService;
    if (settingsService == null || !mounted) return;
    setState(() {
      _runtimeNetworkConfig = RuntimeNetworkConfig.fromSettings(settingsService);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = _settingsService;
    final runtimeNetworkConfig = _runtimeNetworkConfig;

    if (settingsService == null || runtimeNetworkConfig == null) {
      return MaterialApp(
        title: 'Location Protocol Signature Service',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return PrivyAuthProvider(
      config: PrivyAuthConfig(
        appId: dotenv.env['PRIVY_APP_ID'] ?? '',
        clientId: dotenv.env['PRIVY_CLIENT_ID'] ?? '',
        oauthAppUrlScheme: dotenv.env['PRIVY_OAUTH_APP_URL_SCHEME'],
        loginMethods: const [
          LoginMethod.sms,
          LoginMethod.email,
          LoginMethod.google,
          LoginMethod.twitter,
          LoginMethod.discord,
        ],
        autoCreateWallet: true,
      ),
      child: Builder(
        builder: (context) {
          return MultiProvider(
            providers: [
              Provider<ReownService>(create: (_) => ReownService()),
              ChangeNotifierProvider<AppWalletProvider>(
                create: (context) => AppWalletProvider(
                  privyAuth: PrivyAuthProvider.of(context, listen: false),
                  reownService: context.read<ReownService>(),
                  settingsService: settingsService,
                ),
              ),
            ],
            child: MaterialApp(
              title: 'Location Protocol Signature Service',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF1565C0),
                  brightness: Brightness.light,
                ),
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF1565C0),
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),
              home: HomeScreen(
                runtimeNetworkConfig: runtimeNetworkConfig,
                onSettingsChanged: _refreshRuntimeNetworkConfig,
              ),
            ),
          );
        },
      ),
    );
  }
}
