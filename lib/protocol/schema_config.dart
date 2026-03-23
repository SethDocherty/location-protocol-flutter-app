import 'dart:typed_data';

import 'package:location_protocol/location_protocol.dart';

/// App-level schema configuration.
///
/// Defines the Location Protocol schema fields and provides helpers
/// to build LP payloads and user data maps for attestation operations.
class AppSchema {
  AppSchema._();

  /// The app's schema definition: 6 user fields.
  /// LP base fields (lp_version, srs, location_type, location) are
  /// auto-prepended by the library's SchemaDefinition.
  static final SchemaDefinition definition = SchemaDefinition(
    fields: [
      SchemaField(type: 'uint256', name: 'eventTimestamp'),
      SchemaField(type: 'string[]', name: 'recipeType'),
      SchemaField(type: 'bytes[]', name: 'recipePayload'),
      SchemaField(type: 'string[]', name: 'mediaType'),
      SchemaField(type: 'bytes[]', name: 'mediaData'),
      SchemaField(type: 'string', name: 'memo'),
    ],
  );

  /// Computed schema UID (deterministic from the schema string + resolver + revocable).
  static final String schemaUID = SchemaUID.compute(definition);

  /// Builds an [LPPayload] from lat/lng coordinates.
  static LPPayload buildLPPayload({
    required double lat,
    required double lng,
  }) {
    return LPPayload(
      lpVersion: LPVersion.current,
      srs: 'http://www.opengis.net/def/crs/OGC/1.3/CRS84',
      locationType: 'geojson-point',
      location: {
        'type': 'Point',
        'coordinates': [lng, lat], // GeoJSON is [lng, lat]
      },
    );
  }

  /// Builds the user data map matching the schema's 6 user fields.
  static Map<String, dynamic> buildUserData({
    required String memo,
    BigInt? eventTimestamp,
    List<String>? recipeType,
    List<Uint8List>? recipePayload,
    List<String>? mediaType,
    List<Uint8List>? mediaData,
  }) {
    return {
      'eventTimestamp': eventTimestamp ??
          BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      'recipeType': recipeType ?? <String>[],
      'recipePayload': recipePayload ?? <Uint8List>[],
      'mediaType': mediaType ?? <String>[],
      'mediaData': mediaData ?? <Uint8List>[],
      'memo': memo,
    };
  }
}
