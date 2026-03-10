import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:location_protocol_flutter_app/src/eas/abi_encoder.dart';

void main() {
  group('AbiEncoder.encodeUint256', () {
    test('encodes zero as 32 zero bytes', () {
      final result = AbiEncoder.encodeUint256(BigInt.zero);
      expect(result.length, 32);
      expect(result.every((b) => b == 0), isTrue);
    });

    test('encodes 1 correctly (only last byte = 1)', () {
      final result = AbiEncoder.encodeUint256(BigInt.one);
      expect(result.length, 32);
      expect(result[31], 1);
      expect(result.sublist(0, 31).every((b) => b == 0), isTrue);
    });

    test('encodes 256 as two bytes at positions 30 and 31', () {
      final result = AbiEncoder.encodeUint256(BigInt.from(256));
      expect(result[30], 1);
      expect(result[31], 0);
    });

    test('encodes well-known timestamp', () {
      // 1700000000 = 0x6553F100
      const ts = 1700000000;
      final result = AbiEncoder.encodeUint256(BigInt.from(ts));
      expect(result.length, 32);
      // Check big-endian byte order at end
      expect(result[28], 0x65);
      expect(result[29], 0x53);
      expect(result[30], 0xF1);
      expect(result[31], 0x00);
    });
  });

  group('AbiEncoder.padRight32', () {
    test('empty bytes → 0 bytes (no padding needed for empty)', () {
      final result = AbiEncoder.padRight32(Uint8List(0));
      expect(result.length, 0);
    });

    test('1-byte input → 32 bytes right-padded', () {
      final result = AbiEncoder.padRight32(Uint8List.fromList([0x61]));
      expect(result.length, 32);
      expect(result[0], 0x61);
      expect(result.sublist(1).every((b) => b == 0), isTrue);
    });

    test('32-byte input unchanged', () {
      final input = Uint8List.fromList(List.generate(32, (i) => i));
      final result = AbiEncoder.padRight32(input);
      expect(result, equals(input));
    });

    test('33-byte input → 64 bytes', () {
      final input = Uint8List(33);
      final result = AbiEncoder.padRight32(input);
      expect(result.length, 64);
    });
  });

  group('AbiEncoder.encodeStringTail', () {
    test('empty string → length=0 (32 bytes) only', () {
      final result = AbiEncoder.encodeStringTail('');
      expect(result.length, 32);
      expect(result.every((b) => b == 0), isTrue);
    });

    test('"abc" → 64 bytes: length word + data word', () {
      final result = AbiEncoder.encodeStringTail('abc');
      expect(result.length, 64);
      // Length word: 3
      expect(result[31], 3);
      // Data word: 0x61 0x62 0x63 then zeros
      expect(result[32], 0x61); // 'a'
      expect(result[33], 0x62); // 'b'
      expect(result[34], 0x63); // 'c'
      expect(result.sublist(35).every((b) => b == 0), isTrue);
    });

    test('32-char string → 64 bytes (length + 1 data word, no extra padding)', () {
      final s = 'a' * 32;
      final result = AbiEncoder.encodeStringTail(s);
      // 32-byte string fits exactly in one 32-byte slot → no extra padding needed
      expect(result.length, 64); // 32 (length word) + 32 (data, already 32-byte aligned)
    });

    test('33-char string → 96 bytes (length + 64 bytes data)', () {
      final s = 'a' * 33;
      final result = AbiEncoder.encodeStringTail(s);
      // 32 (length word) + 64 (data padded to next multiple of 32)
      expect(result.length, 96);
    });
  });

  group('AbiEncoder.encodeStringArray', () {
    test('empty array → 32 bytes (count=0)', () {
      final result = AbiEncoder.encodeStringArray([]);
      expect(result.length, 32);
      expect(result.every((b) => b == 0), isTrue);
    });

    test('single element: layout count + offset + data', () {
      final result = AbiEncoder.encodeStringArray(['abc']);
      // count (32) + offset (32) + length (32) + data (32) = 128
      expect(result.length, 128);
      // count = 1
      expect(result[31], 1);
      // offset[0] = 32 (after the 1 offset word, pointing to the tail)
      expect(result[32 + 31], 32);
      // length of 'abc' = 3
      expect(result[64 + 31], 3);
      // 'abc'
      expect(result[96], 0x61);
      expect(result[97], 0x62);
      expect(result[98], 0x63);
    });

    test('two elements have correct offsets', () {
      final result = AbiEncoder.encodeStringArray(['abc', 'de']);
      // count (32) + 2 offsets (64) + tail("abc") (64) + tail("de") (64) = 224
      expect(result.length, 224);
      // count = 2
      expect(result[31], 2);
      // offset[0] = content area start = 2*32 = 64
      expect(result[32 + 31], 64);
      // offset[1] = 64 + sizeof(tail("abc")=64) = 128
      expect(result[64 + 31], 128);
    });
  });

  group('AbiEncoder.encodeBytesArray', () {
    test('empty array → 32 bytes (count=0)', () {
      final result = AbiEncoder.encodeBytesArray([]);
      expect(result.length, 32);
    });

    test('single element "0xdeadbeef"', () {
      final result = AbiEncoder.encodeBytesArray(['0xdeadbeef']);
      // count (32) + offset (32) + length (32) + data (32) = 128
      expect(result.length, 128);
      // count = 1
      expect(result[31], 1);
      // offset[0] = 32
      expect(result[32 + 31], 32);
      // length of 0xdeadbeef = 4
      expect(result[64 + 31], 4);
      // data: DE AD BE EF
      expect(result[96], 0xDE);
      expect(result[97], 0xAD);
      expect(result[98], 0xBE);
      expect(result[99], 0xEF);
    });
  });

  group('AbiEncoder.encodeFields', () {
    test('head is always 9 * 32 = 288 bytes', () {
      final result = AbiEncoder.encodeFields(
        eventTimestamp: 1700000000,
        srs: 'EPSG:4326',
        locationType: 'geojson-point',
        location: '{"type":"Point","coordinates":[-122.4194,37.7749]}',
        recipeType: [],
        recipePayload: [],
        mediaType: [],
        mediaData: [],
        memo: '',
      );
      // Verify the first field (static uint256) is in the head
      expect(result.length, greaterThanOrEqualTo(288));

      // Head word 0: eventTimestamp = 1700000000 = 0x6553F100
      expect(result[28], 0x65);
      expect(result[29], 0x53);
      expect(result[30], 0xF1);
      expect(result[31], 0x00);

      // Head word 1: offset to srs tail = 288 exactly
      final offset = _readBigEndianInt(result, 32, 64);
      expect(offset, 288);
    });

    test('deterministic encoding: same inputs → same output', () {
      const ts = 1700000000;
      const srs = 'EPSG:4326';
      const loc = '{"type":"Point","coordinates":[-122.4194,37.7749]}';
      const memo = 'hello';

      final r1 = AbiEncoder.encodeFields(
        eventTimestamp: ts,
        srs: srs,
        locationType: 'geojson-point',
        location: loc,
        recipeType: [],
        recipePayload: [],
        mediaType: [],
        mediaData: [],
        memo: memo,
      );
      final r2 = AbiEncoder.encodeFields(
        eventTimestamp: ts,
        srs: srs,
        locationType: 'geojson-point',
        location: loc,
        recipeType: [],
        recipePayload: [],
        mediaType: [],
        mediaData: [],
        memo: memo,
      );
      expect(r1, equals(r2));
    });

    test('empty memo uses empty string tail (32 bytes)', () {
      final result = AbiEncoder.encodeFields(
        eventTimestamp: 0,
        srs: '',
        locationType: '',
        location: '',
        recipeType: [],
        recipePayload: [],
        mediaType: [],
        mediaData: [],
        memo: '',
      );
      // With all empty strings and empty arrays the tail for each string
      // is 32 bytes (zero length), and empty array tail is 32 bytes.
      // Total = 288 (head) + 8 tails * 32 = 544
      expect(result.length, 288 + 8 * 32);
    });

    test('srs offset matches actual srs tail position', () {
      const srsStr = 'EPSG:4326';
      final result = AbiEncoder.encodeFields(
        eventTimestamp: 0,
        srs: srsStr,
        locationType: '',
        location: '',
        recipeType: [],
        recipePayload: [],
        mediaType: [],
        mediaData: [],
        memo: '',
      );

      // Read srs offset from head word 1
      final srsOffset = _readBigEndianInt(result, 32, 64);

      // At that offset, read the length
      final srsLen =
          _readBigEndianInt(result, srsOffset, srsOffset + 32);
      expect(srsLen, utf8.encode(srsStr).length);
    });
  });
}

/// Reads a big-endian integer from [bytes] in the range [start, end).
int _readBigEndianInt(Uint8List bytes, int start, int end) {
  var value = 0;
  for (int i = start; i < end; i++) {
    value = (value << 8) | bytes[i];
  }
  return value;
}
