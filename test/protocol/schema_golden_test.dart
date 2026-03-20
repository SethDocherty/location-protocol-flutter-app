import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:location_protocol_flutter_app/protocol/schema_config.dart';

void main() {
  group('Schema golden values', () {
    test('schema UID matches SchemaUID.compute() for our definition', () {
      final computed = SchemaUID.compute(AppSchema.definition);
      expect(AppSchema.schemaUID, computed);
    });

    test('schema string matches expected EAS format', () {
      final str = AppSchema.definition.toEASSchemaString();
      // Should contain all 10 fields: 4 LP base + 6 user
      expect(str, contains('string lp_version'));
      expect(str, contains('string srs'));
      expect(str, contains('string location_type'));
      expect(str, contains('string location'));
      expect(str, contains('uint256 eventTimestamp'));
      expect(str, contains('string[] recipeType'));
      expect(str, contains('bytes[] recipePayload'));
      expect(str, contains('string[] mediaType'));
      expect(str, contains('bytes[] mediaData'));
      expect(str, contains('string memo'));
    });

    test('LP payload encodes with correct SRS', () {
      final payload = AppSchema.buildLPPayload(lat: 0, lng: 0);
      expect(payload.srs, 'http://www.opengis.net/def/crs/OGC/1.3/CRS84');
    });

    test('LP payload uses current LP version', () {
      final payload = AppSchema.buildLPPayload(lat: 0, lng: 0);
      expect(payload.lpVersion, LPVersion.current);
    });

    test('ABI encode round-trips without error', () {
      final payload = AppSchema.buildLPPayload(lat: 37.7749, lng: -122.4194);
      final userData = AppSchema.buildUserData(
        memo: 'golden test',
        eventTimestamp: BigInt.from(1700000000),
      );

      final encoded = AbiEncoder.encode(
        schema: AppSchema.definition,
        lpPayload: payload,
        userData: userData,
      );

      expect(encoded, isA<Uint8List>());
      expect(encoded.isNotEmpty, isTrue);
    });
  });
}
