import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/home_screen.dart';
import 'privy/privy_module.dart';
import 'src/services/location_protocol_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const LocationProtocolApp());
}

class LocationProtocolApp extends StatelessWidget {
  const LocationProtocolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LocationProtocolProvider(
      child: PrivyAuthProvider(
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
      ),
    );
  }
}
