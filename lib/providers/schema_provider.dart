import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Default user-facing fields (LP base fields added automatically by the library).
final List<SchemaField> _defaultUserFields = [
  SchemaField(type: 'uint256', name: 'eventTimestamp'),
  SchemaField(type: 'string[]', name: 'recipeType'),
  SchemaField(type: 'bytes[]', name: 'recipePayload'),
  SchemaField(type: 'string[]', name: 'mediaType'),
  SchemaField(type: 'bytes[]', name: 'mediaData'),
  SchemaField(type: 'string', name: 'memo'),
];

class SchemaProvider extends ChangeNotifier {
  List<SchemaField> _userFields;
  late SchemaDefinition _definition;
  late String _schemaUID;

  static const String _prefsKey = 'schema_provider_fields';

  SchemaProvider({List<SchemaField>? initialFields})
      : _userFields = List.from(initialFields ?? _defaultUserFields) {
    _rebuild();
  }

  /// Factory constructor that loads the persisted schema from SharedPreferences.
  /// Falls back to default if nothing is saved or data is corrupt.
  static Future<SchemaProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json == null) return SchemaProvider();
    try {
      final list = jsonDecode(json) as List<dynamic>;
      final fields = list
          .cast<Map<String, dynamic>>()
          .map((m) => SchemaField(type: m['type'] as String, name: m['name'] as String))
          .toList();
      return SchemaProvider(initialFields: fields);
    } catch (_) {
      return SchemaProvider();
    }
  }

  /// Persists the current user fields to SharedPreferences.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(
      _userFields.map((f) => {'type': f.type, 'name': f.name}).toList(),
    );
    await prefs.setString(_prefsKey, json);
  }

  SchemaDefinition get definition => _definition;
  String get schemaUID => _schemaUID;

  /// Returns an unmodifiable snapshot. Use length/name comparisons to detect
  /// changes — do NOT use identity (!=) because a new list instance is returned
  /// on each call.
  List<SchemaField> get userFields => List.unmodifiable(_userFields);

  void addField(SchemaField field) {
    _userFields.add(field);
    _rebuild();
    notifyListeners();
    unawaited(save());
  }

  void removeField(String name) {
    _userFields.removeWhere((f) => f.name == name);
    _rebuild();
    notifyListeners();
    unawaited(save());
  }

  void setSchema(List<SchemaField> fields) {
    _userFields = List.from(fields);
    _rebuild();
    notifyListeners();
    unawaited(save());
  }

  void resetToDefault() {
    _userFields = List.from(_defaultUserFields);
    _rebuild();
    notifyListeners();
    unawaited(save());
  }

  void _rebuild() {
    _definition = SchemaDefinition(fields: _userFields);
    _schemaUID = SchemaUID.compute(_definition);
  }
}
