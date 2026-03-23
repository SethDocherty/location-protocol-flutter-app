import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/screens/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('HomeScreen without PrivyAuthProvider throws FlutterError', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    // HomeScreen calls context.watch<AppWalletProvider>(), which throws if
    // there's no ancestor Provider.
    expect(tester.takeException(), isNotNull);
  });
}
