import 'package:flutter_test/flutter_test.dart';

import 'package:location_protocol_flutter_app/main.dart';

void main() {
  testWidgets('Home screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LocationProtocolApp());

    // Verify that our app title is shown.
    expect(find.text('Location Protocol'), findsOneWidget);
    expect(find.text('Location Protocol\nSignature Service'), findsOneWidget);

    // Verify that the navigation buttons are present.
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Sign Attestation'), findsOneWidget);
    expect(find.text('Verify Attestation'), findsOneWidget);
  }, skip: true);
}
