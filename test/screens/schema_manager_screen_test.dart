import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/providers/app_wallet_provider.dart';
import 'package:location_protocol_flutter_app/providers/schema_provider.dart';
import 'package:location_protocol_flutter_app/protocol/attestation_service.dart';
import 'package:location_protocol_flutter_app/screens/schema_manager_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSchemaProvider extends Mock implements SchemaProvider {}
class MockAppWalletProvider extends Mock implements AppWalletProvider {}
class MockAttestationService extends Mock implements AttestationService {}

void main() {
  late MockSchemaProvider mockSchemaProvider;
  late MockAppWalletProvider mockAppWalletProvider;
  late MockAttestationService mockAttestationService;

  setUpAll(() {
    registerFallbackValue(SchemaField(type: 'string', name: 'fallback'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockSchemaProvider = MockSchemaProvider();
    mockAppWalletProvider = MockAppWalletProvider();
    mockAttestationService = MockAttestationService();

    when(() => mockSchemaProvider.userFields).thenReturn([
      SchemaField(type: 'string', name: 'memo'),
    ]);
    when(() => mockSchemaProvider.schemaUID).thenReturn('0x123');
    when(() => mockSchemaProvider.definition).thenReturn(
      SchemaDefinition(fields: [SchemaField(type: 'string', name: 'memo')]),
    );

    when(() => mockAppWalletProvider.isConnected).thenReturn(true);
    when(() => mockAppWalletProvider.walletAddress).thenReturn('0xaddress');
    
    when(() => mockAttestationService.chainId).thenReturn(11155111);
    when(() => mockAttestationService.isSchemaUidRegistered(any())).thenAnswer((_) async => false);
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SchemaProvider>.value(value: mockSchemaProvider),
        ChangeNotifierProvider<AppWalletProvider>.value(value: mockAppWalletProvider),
      ],
      child: MaterialApp(
        home: SchemaManagerScreen(service: mockAttestationService),
      ),
    );
  }

  testWidgets('SchemaManagerScreen shows current user fields', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    expect(find.text('memo'), findsOneWidget);
    expect(find.text('string'), findsOneWidget);
  });

  testWidgets('SchemaManagerScreen shows schema UID', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    expect(find.textContaining('0x123'), findsOneWidget);
  });

  testWidgets('clicking Add Field opens dialog', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Add Schema Field'), findsOneWidget);
  });
}
