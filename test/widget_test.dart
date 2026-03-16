import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:location_protocol_flutter_app/screens/home_screen.dart';

void main() {
  testWidgets('Home screen requires PrivyAuthProvider',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );

    expect(tester.takeException(), isA<FlutterError>());
  });
}
