import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/providers/schema_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SchemaProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts with 6 default user fields', () {
      final provider = SchemaProvider();
      expect(provider.userFields.length, 6);
    });

    test('schemaUID is a 66-char 0x-prefixed hex string', () {
      final provider = SchemaProvider();
      expect(provider.schemaUID, startsWith('0x'));
      expect(provider.schemaUID.length, 66);
    });

    test('addField appends a field and updates UID', () {
      final provider = SchemaProvider();
      final originalUID = provider.schemaUID;
      provider.addField(SchemaField(type: 'string', name: 'newField'));
      expect(provider.userFields.length, 7);
      expect(provider.schemaUID, isNot(originalUID));
    });

    test('removeField removes field by name and updates UID', () {
      final provider = SchemaProvider();
      final originalUID = provider.schemaUID;
      provider.removeField('memo');
      expect(provider.userFields.any((f) => f.name == 'memo'), isFalse);
      expect(provider.schemaUID, isNot(originalUID));
    });

    test('setSchema replaces all fields', () {
      final provider = SchemaProvider();
      provider.setSchema([SchemaField(type: 'string', name: 'only')]);
      expect(provider.userFields.length, 1);
      expect(provider.userFields.first.name, 'only');
    });

    test('resetToDefault restores 6 default fields', () {
      final provider = SchemaProvider();
      provider.removeField('memo');
      provider.resetToDefault();
      expect(provider.userFields.length, 6);
    });

    test('notifies listeners on mutation', () {
      final provider = SchemaProvider();
      int calls = 0;
      provider.addListener(() => calls++);
      provider.addField(SchemaField(type: 'bool', name: 'flag'));
      expect(calls, 1);
    });

    test('userFields returns a new list instance each call (safe to compare by value)', () {
      final provider = SchemaProvider();
      expect(identical(provider.userFields, provider.userFields), isFalse);
    });
  });

  group('SchemaProvider persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('SchemaProvider.load() returns default when prefs are empty', () async {
      final provider = await SchemaProvider.load();
      expect(provider.userFields.length, 6);
    });

    test('save() and load() round-trips fields', () async {
      final provider = await SchemaProvider.load();
      provider.addField(SchemaField(type: 'bool', name: 'testFlag'));
      await provider.save();

      final reloaded = await SchemaProvider.load();
      expect(reloaded.userFields.length, 7);
      expect(reloaded.userFields.last.name, 'testFlag');
    });

    test('load() falls back to default on corrupt data', () async {
      SharedPreferences.setMockInitialValues({
        'schema_provider_fields': 'not-valid-json!!!',
      });
      final provider = await SchemaProvider.load();
      expect(provider.userFields.length, 6);
    });
  });
}
