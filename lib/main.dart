import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'privy/privy_module.dart';
import 'screens/home_screen.dart';
import 'services/reown_service.dart';
import 'providers/app_wallet_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const LocationProtocolApp());
}

class LocationProtocolApp extends StatelessWidget {
  const LocationProtocolApp({super.key});

  @override
  Widget build(BuildContext context) {
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
          LoginMethod.siwe,
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
                  privyAuth: PrivyAuthProvider.of(context),
                  reownService: context.read<ReownService>(),
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
              home: const HomeScreen(),
            ),
          );
        },
      ),
    );
  }
}
