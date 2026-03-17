import 'dart:convert';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:location_protocol/location_protocol.dart'
    show AbiEncoder as LibraryAbiEncoder, LPPayload;

import '../models/location_attestation.dart';
import 'schema_config.dart';

/// Solidity ABI encoder for Location Protocol EAS attestations.
///
/// [encodeAttestationData] delegates to the library's [LibraryAbiEncoder] which
/// implements the LP-compliant schema (`lp_version, srs, location_type,
/// location, ...user fields`).  The lower-level helpers ([encodeUint256],
/// [padRight32], etc.) are kept for use by other parts of the codebase.
class AbiEncoder {
  // ---------------------------------------------------------------------------
  // LP-compliant top-level encoder (delegates to library)
  // ---------------------------------------------------------------------------

  /// ABI-encodes all schema fields from [attestation] according to the
  /// LP-compliant Location Protocol EAS schema.
  static Uint8List encodeAttestationData(
      UnsignedLocationAttestation attestation) {
    final lpPayload = LPPayload(
      lpVersion: attestation.lpVersion,
      srs: attestation.srs,
      locationType: attestation.locationType,
      location: attestation.location,
    );

    final userData = <String, dynamic>{
      'eventTimestamp': BigInt.from(attestation.eventTimestamp),
      'recipeType': attestation.recipeType,
      'recipePayload': attestation.recipePayload
          .map((h) => _hexToBytes(h))
          .toList(),
      'mediaType': attestation.mediaType,
      'mediaData': attestation.mediaData,
      'memo': attestation.memo ?? '',
    };

    return LibraryAbiEncoder.encode(
      schema: SchemaConfig.locationSchema,
      lpPayload: lpPayload,
      userData: userData,
    );
  }

  // ---------------------------------------------------------------------------
  // LP-compliant top-level decoder
  // ---------------------------------------------------------------------------

  /// Decodes ABI-encoded bytes back into the ten LP-compliant schema fields.
  ///
  /// The encoding layout (10 fields, head = 10 * 32 = 320 bytes):
  /// - word 0: offset to lp_version (string)
  /// - word 1: offset to srs (string)
  /// - word 2: offset to location_type (string)
  /// - word 3: offset to location (string)
  /// - word 4: eventTimestamp (uint256, static)
  /// - word 5: offset to recipeType (string[])
  /// - word 6: offset to recipePayload (bytes[])
  /// - word 7: offset to mediaType (string[])
  /// - word 8: offset to mediaData (string[])
  /// - word 9: offset to memo (string)
  static Map<String, dynamic> decodeAttestationData(Uint8List data) {
    final lpVersion = _decodeStringAt(data, _decodeUint256(data.sublist(0, 32)).toInt());
    final srs = _decodeStringAt(data, _decodeUint256(data.sublist(32, 64)).toInt());
    final locationType = _decodeStringAt(data, _decodeUint256(data.sublist(64, 96)).toInt());
    final location = _decodeStringAt(data, _decodeUint256(data.sublist(96, 128)).toInt());
    final eventTimestamp = _decodeUint256(data.sublist(128, 160)).toInt();
    final recipeType = _decodeStringArrayAt(data, _decodeUint256(data.sublist(160, 192)).toInt());
    final recipePayload = _decodeBytesArrayAt(data, _decodeUint256(data.sublist(192, 224)).toInt());
    final mediaType = _decodeStringArrayAt(data, _decodeUint256(data.sublist(224, 256)).toInt());
    final mediaData = _decodeStringArrayAt(data, _decodeUint256(data.sublist(256, 288)).toInt());
    final memo = _decodeStringAt(data, _decodeUint256(data.sublist(288, 320)).toInt());

    return {
      'lpVersion': lpVersion,
      'eventTimestamp': eventTimestamp,
      'srs': srs,
      'locationType': locationType,
      'location': location,
      'recipeType': recipeType,
      'recipePayload': recipePayload,
      'mediaType': mediaType,
      'mediaData': mediaData,
      'memo': memo.isEmpty ? null : memo,
    };
  }

  // ---------------------------------------------------------------------------
  // Primitive encoders (used by EIP712Signer and tests)
  // ---------------------------------------------------------------------------

  /// Encodes [value] as a 32-byte big-endian unsigned integer (uint256).
  static Uint8List encodeUint256(BigInt value) {
    assert(value >= BigInt.zero && value < BigInt.two.pow(256));
    final bytes = Uint8List(32);
    var v = value;
    for (int i = 31; i >= 0; i--) {
      bytes[i] = (v & BigInt.from(0xFF)).toInt();
      v = v >> 8;
    }
    return bytes;
  }

  /// Right-pads [data] with zeros to the next multiple of 32 bytes.
  static Uint8List padRight32(Uint8List data) {
    final paddedLen = ((data.length + 31) ~/ 32) * 32;
    if (paddedLen == data.length) return data;
    final padded = Uint8List(paddedLen);
    padded.setRange(0, data.length, data);
    return padded;
  }

  // ---------------------------------------------------------------------------
  // Dynamic type tail encoders (used by encodeFields and tests)
  // ---------------------------------------------------------------------------

  /// Encodes one `string` value as its length-prefixed, right-padded bytes.
  ///
  /// Returns: `uint256(len) ++ right_pad_32(utf8_bytes)`.
  static Uint8List encodeStringTail(String s) {
    final strBytes = Uint8List.fromList(utf8.encode(s));
    return _concat([
      encodeUint256(BigInt.from(strBytes.length)),
      padRight32(strBytes),
    ]);
  }

  /// Encodes one `bytes` value (raw bytes) as its length-prefixed, padded form.
  ///
  /// Returns: `uint256(len) ++ right_pad_32(bytes)`.
  static Uint8List encodeBytesValueTail(Uint8List b) {
    return _concat([
      encodeUint256(BigInt.from(b.length)),
      padRight32(b),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Array encoders (used by encodeFields and tests)
  // ---------------------------------------------------------------------------

  /// Encodes a `string[]` value.
  static Uint8List encodeStringArray(List<String> arr) {
    final count = encodeUint256(BigInt.from(arr.length));
    if (arr.isEmpty) return count;

    final tails = arr.map(encodeStringTail).toList();
    return _encodeArrayWithTails(count, tails);
  }

  /// Encodes a `bytes[]` value.
  static Uint8List encodeBytesArray(List<String> arr) {
    final count = encodeUint256(BigInt.from(arr.length));
    if (arr.isEmpty) return count;

    final tails = arr.map((s) {
      final raw = _hexStringToBytes(s);
      return encodeBytesValueTail(raw);
    }).toList();
    return _encodeArrayWithTails(count, tails);
  }

  // ---------------------------------------------------------------------------
  // Legacy field encoder (OLD schema layout; used by unit tests only)
  // ---------------------------------------------------------------------------

  /// Encodes the nine OLD schema fields given as named parameters.
  ///
  /// Kept for backward compatibility with existing unit tests.
  /// For LP-compliant encoding use [encodeAttestationData].
  static Uint8List encodeFields({
    required int eventTimestamp,
    required String srs,
    required String locationType,
    required String location,
    required List<String> recipeType,
    required List<String> recipePayload,
    required List<String> mediaType,
    required List<String> mediaData,
    required String memo,
  }) {
    const headSize = 9 * 32;

    final dynamicTails = [
      encodeStringTail(srs),
      encodeStringTail(locationType),
      encodeStringTail(location),
      encodeStringArray(recipeType),
      encodeBytesArray(recipePayload),
      encodeStringArray(mediaType),
      encodeStringArray(mediaData),
      encodeStringTail(memo),
    ];

    final offsets = <int>[];
    var offset = headSize;
    for (final tail in dynamicTails) {
      offsets.add(offset);
      offset += tail.length;
    }

    final head = _concat([
      encodeUint256(BigInt.from(eventTimestamp)),
      ...offsets.map((o) => encodeUint256(BigInt.from(o))),
    ]);

    return _concat([head, ...dynamicTails]);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (clean.isEmpty) return Uint8List(0);
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static BigInt _decodeUint256(Uint8List word) {
    BigInt result = BigInt.zero;
    for (int i = 0; i < 32; i++) {
      result = (result << 8) | BigInt.from(word[i]);
    }
    return result;
  }

  static String _decodeStringAt(Uint8List data, int offset) {
    final len = _decodeUint256(data.sublist(offset, offset + 32)).toInt();
    final strBytes = data.sublist(offset + 32, offset + 32 + len);
    return utf8.decode(strBytes);
  }

  static List<String> _decodeStringArrayAt(Uint8List data, int offset) {
    final count = _decodeUint256(data.sublist(offset, offset + 32)).toInt();
    if (count == 0) return [];

    final results = <String>[];
    for (int i = 0; i < count; i++) {
      final itemOffset = _decodeUint256(
          data.sublist(offset + 32 + i * 32, offset + 64 + i * 32)).toInt();
      results.add(_decodeStringAt(data, offset + 32 + itemOffset));
    }
    return results;
  }

  static List<String> _decodeBytesArrayAt(Uint8List data, int offset) {
    final count = _decodeUint256(data.sublist(offset, offset + 32)).toInt();
    if (count == 0) return [];

    final results = <String>[];
    for (int i = 0; i < count; i++) {
      final itemOffset = _decodeUint256(
          data.sublist(offset + 32 + i * 32, offset + 64 + i * 32)).toInt();
      final bytesOffset = offset + 32 + itemOffset;
      final len = _decodeUint256(
          data.sublist(bytesOffset, bytesOffset + 32)).toInt();
      final rawBytes = data.sublist(bytesOffset + 32, bytesOffset + 32 + len);
      results.add(
          '0x${rawBytes.map((b) => b.toRadixString(16).padLeft(2, "0")).join()}');
    }
    return results;
  }

  static Uint8List _encodeArrayWithTails(
      Uint8List countWord, List<Uint8List> tails) {
    final contentAreaOffset = tails.length * 32;
    var cur = contentAreaOffset;
    final offsets = <Uint8List>[];
    for (final t in tails) {
      offsets.add(encodeUint256(BigInt.from(cur)));
      cur += t.length;
    }
    return _concat([countWord, ...offsets, ...tails]);
  }

  static Uint8List _hexStringToBytes(String hex) {
    if (hex.isEmpty) return Uint8List(0);
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (clean.isEmpty) return Uint8List(0);
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static Uint8List _concat(List<Uint8List> parts) {
    final total = parts.fold(0, (sum, p) => sum + p.length);
    final result = Uint8List(total);
    var pos = 0;
    for (final part in parts) {
      result.setRange(pos, pos + part.length, part);
      pos += part.length;
    }
    return result;
  }
}
