import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';

void main() {
  group('AppSchema', () {
    test('defines 6 user fields', () {
      expect(AppSchema.definition.fields.length, 6);
    });

    test('user fields match LP spec ordering', () {
      final names = AppSchema.definition.fields.map((f) => f.name).toList();
      expect(names, [
        'eventTimestamp',
        'recipeType',
        'recipePayload',
        'mediaType',
        'mediaData',
        'memo',
      ]);
    });

    test('allFields includes 4 LP base fields + 6 user fields', () {
      expect(AppSchema.definition.allFields.length, 10);
    });

    test('schema UID is a 66-char 0x-prefixed hex string', () {
      final uid = AppSchema.schemaUID;
      expect(uid, startsWith('0x'));
      expect(uid.length, 66);
    });

    test('schema UID is deterministic', () {
      expect(AppSchema.schemaUID, AppSchema.schemaUID);
    });

    test('schema is revocable by default', () {
      expect(AppSchema.definition.revocable, isTrue);
    });

    test('toEASSchemaString produces comma-separated type-name pairs', () {
      final str = AppSchema.definition.toEASSchemaString();
      expect(str, contains('string lp_version'));
      expect(str, contains('string memo'));
      expect(str, contains('uint256 eventTimestamp'));
    });
  });

  group('AppSchema.defaultLPPayload', () {
    test('creates LPPayload with correct version', () {
      final payload = AppSchema.buildLPPayload(lat: 37.7749, lng: -122.4194);
      expect(payload.lpVersion, LPVersion.current);
    });

    test('creates GeoJSON point from coordinates', () {
      final payload = AppSchema.buildLPPayload(lat: 37.7749, lng: -122.4194);
      final loc = payload.location as Map<String, dynamic>;
      expect(loc['type'], 'Point');
      final coords = loc['coordinates'] as List;
      expect(coords[0], -122.4194); // lng first
      expect(coords[1], 37.7749);   // lat second
    });

    test('uses CRS84 SRS', () {
      final payload = AppSchema.buildLPPayload(lat: 0, lng: 0);
      expect(payload.srs, 'http://www.opengis.net/def/crs/OGC/1.3/CRS84');
    });

    test('uses geojson-point location type', () {
      final payload = AppSchema.buildLPPayload(lat: 0, lng: 0);
      expect(payload.locationType, 'geojson-point');
    });
  });

  group('AppSchema.buildUserData', () {
    test('produces map with all 6 user fields', () {
      final data = AppSchema.buildUserData(memo: 'test');
      expect(data.keys, containsAll([
        'eventTimestamp',
        'recipeType',
        'recipePayload',
        'mediaType',
        'mediaData',
        'memo',
      ]));
    });

    test('eventTimestamp is a BigInt', () {
      final data = AppSchema.buildUserData(memo: 'test');
      expect(data['eventTimestamp'], isA<BigInt>());
    });

    test('uses provided timestamp when given', () {
      final data = AppSchema.buildUserData(
        memo: 'test',
        eventTimestamp: BigInt.from(1700000000),
      );
      expect(data['eventTimestamp'], BigInt.from(1700000000));
    });

    test('defaults empty lists for recipe and media fields', () {
      final data = AppSchema.buildUserData(memo: 'test');
      expect(data['recipeType'], <String>[]);
      expect(data['recipePayload'], <List<int>>[]);
      expect(data['mediaType'], <String>[]);
      expect(data['mediaData'], <List<int>>[]);
    });
  });
}
