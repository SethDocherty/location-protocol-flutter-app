import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:location_protocol_flutter_app/src/builder/attestation_builder.dart';
import 'package:location_protocol_flutter_app/src/models/location_attestation.dart';

void main() {
  group('AttestationBuilder.fromCoordinates', () {
    test('produces GeoJSON Point location', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 37.7749,
        longitude: -122.4194,
      );
      final map = jsonDecode(att.location) as Map<String, dynamic>;
      expect(map['type'], 'Point');
      final coords = map['coordinates'] as List<dynamic>;
      expect(coords[0], closeTo(-122.4194, 0.0001)); // longitude first
      expect(coords[1], closeTo(37.7749, 0.0001));   // latitude second
    });

    test('sets srs to EPSG:4326', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 0.0,
        longitude: 0.0,
      );
      expect(att.srs, 'EPSG:4326');
    });

    test('sets locationType to geojson-point', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 0.0,
        longitude: 0.0,
      );
      expect(att.locationType, 'geojson-point');
    });

    test('recipeType and recipePayload are empty', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 0.0,
        longitude: 0.0,
      );
      expect(att.recipeType, isEmpty);
      expect(att.recipePayload, isEmpty);
    });

    test('uses provided eventTimestamp', () {
      const ts = 1700000000;
      final att = AttestationBuilder.fromCoordinates(
        latitude: 0.0,
        longitude: 0.0,
        eventTimestamp: ts,
      );
      expect(att.eventTimestamp, ts);
    });

    test('defaults eventTimestamp to current time when not provided', () {
      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final att = AttestationBuilder.fromCoordinates(
        latitude: 0.0,
        longitude: 0.0,
      );
      final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(att.eventTimestamp, greaterThanOrEqualTo(before));
      expect(att.eventTimestamp, lessThanOrEqualTo(after));
    });

    test('sets memo field', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 0.0,
        longitude: 0.0,
        memo: 'hello world',
      );
      expect(att.memo, 'hello world');
    });

    test('memo is null when not provided', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 0.0,
        longitude: 0.0,
      );
      expect(att.memo, isNull);
    });

    test('revocable defaults to true', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 0.0,
        longitude: 0.0,
      );
      expect(att.revocable, isTrue);
    });

    test('expirationTime defaults to 0', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 0.0,
        longitude: 0.0,
      );
      expect(att.expirationTime, 0);
    });
  });

  group('AttestationBuilder.parseCoordinates', () {
    test('parses GeoJSON Point back to lat/lng', () {
      const lat = 48.8566;
      const lng = 2.3522;
      final att = AttestationBuilder.fromCoordinates(
        latitude: lat,
        longitude: lng,
      );
      final coords = AttestationBuilder.parseCoordinates(att);
      expect(coords, isNotNull);
      expect(coords!['latitude'], closeTo(lat, 0.0001));
      expect(coords['longitude'], closeTo(lng, 0.0001));
    });

    test('returns null for non-Point GeoJSON', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 0,
        longitude: 0,
      );
      // Manually override to a LineString
      final modified = att.copyWith(
        location: '{"type":"LineString","coordinates":[[0,0],[1,1]]}',
      );
      expect(AttestationBuilder.parseCoordinates(modified), isNull);
    });

    test('returns null for invalid JSON', () {
      final att = AttestationBuilder.fromCoordinates(
        latitude: 0,
        longitude: 0,
      );
      final modified = att.copyWith(location: 'not-json');
      expect(AttestationBuilder.parseCoordinates(modified), isNull);
    });
  });
}

extension on UnsignedLocationAttestation {
  UnsignedLocationAttestation copyWith({String? location}) =>
      UnsignedLocationAttestation(
        eventTimestamp: eventTimestamp,
        srs: srs,
        locationType: locationType,
        location: location ?? this.location,
        recipeType: recipeType,
        recipePayload: recipePayload,
        mediaType: mediaType,
        mediaData: mediaData,
        memo: memo,
        recipient: recipient,
        expirationTime: expirationTime,
        revocable: revocable,
      );
}
