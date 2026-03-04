import 'dart:convert';

import '../models/location_attestation.dart';

/// Builds [UnsignedLocationAttestation] instances from high-level inputs such
/// as geographic coordinates.
class AttestationBuilder {
  /// Creates an [UnsignedLocationAttestation] from WGS-84 coordinates.
  ///
  /// [latitude] and [longitude] must be in decimal degrees (EPSG:4326).
  /// [memo] is an optional human-readable note.
  /// [eventTimestamp] defaults to the current Unix time in seconds.
  static UnsignedLocationAttestation fromCoordinates({
    required double latitude,
    required double longitude,
    String? memo,
    int? eventTimestamp,
    String? recipient,
    int? expirationTime,
    bool revocable = true,
    List<String> mediaType = const [],
    List<String> mediaData = const [],
  }) {
    final ts =
        eventTimestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final locationJson = jsonEncode({
      'type': 'Point',
      'coordinates': [longitude, latitude],
    });

    return UnsignedLocationAttestation(
      eventTimestamp: ts,
      srs: 'EPSG:4326',
      locationType: 'geojson-point',
      location: locationJson,
      recipeType: const [],
      recipePayload: const [],
      mediaType: mediaType,
      mediaData: mediaData,
      memo: memo,
      recipient: recipient,
      expirationTime: expirationTime ?? 0,
      revocable: revocable,
    );
  }

  /// Parses the [location] JSON field and returns a map with
  /// `{'latitude': ..., 'longitude': ...}` or `null` if the format is
  /// not a GeoJSON Point.
  static Map<String, double>? parseCoordinates(
      UnsignedLocationAttestation attestation) {
    try {
      final decoded = jsonDecode(attestation.location) as Map<String, dynamic>;
      if (decoded['type'] != 'Point') return null;
      final coords = decoded['coordinates'] as List<dynamic>;
      return {
        'longitude': (coords[0] as num).toDouble(),
        'latitude': (coords[1] as num).toDouble(),
      };
    } catch (_) {
      return null;
    }
  }
}
