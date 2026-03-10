import 'dart:convert';
import 'dart:typed_data';

import 'package:web3dart/crypto.dart' as eth_crypto;

import '../models/location_attestation.dart';

/// Implements Solidity ABI encoding/decoding for the Location Protocol EAS schema:
///
/// ```
/// uint256 eventTimestamp, string srs, string locationType, string location,
/// string[] recipeType, bytes[] recipePayload, string[] mediaType,
/// string[] mediaData, string memo
/// ```
///
/// Encoding follows the [Solidity ABI specification](https://docs.soliditylang.org/en/latest/abi-spec.html).
class AbiEncoder {
  // ---------------------------------------------------------------------------
  // Primitive encoders
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
  // Dynamic type tail encoders
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
  // Array encoders
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
  // Top-level attestation encoder
  // ---------------------------------------------------------------------------

  /// ABI-encodes all nine fields from an [UnsignedLocationAttestation]
  /// according to the Location Protocol EAS schema.
  static Uint8List encodeAttestationData(
      UnsignedLocationAttestation attestation) {
    return encodeFields(
      eventTimestamp: attestation.eventTimestamp,
      srs: attestation.srs,
      locationType: attestation.locationType,
      location: attestation.location,
      recipeType: attestation.recipeType,
      recipePayload: attestation.recipePayload,
      mediaType: attestation.mediaType,
      mediaData: attestation.mediaData,
      memo: attestation.memo ?? '',
    );
  }

  /// Encodes the nine schema fields given as named parameters.
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
  // Decoding
  // ---------------------------------------------------------------------------

  /// Decodes ABI-encoded bytes back into the nine schema fields.
  static Map<String, dynamic> decodeAttestationData(Uint8List data) {
    // 9 fields, each is a 32-byte word.
    final eventTimestamp = _decodeUint256(data.sublist(0, 32)).toInt();

    // The next 8 words are offsets to dynamic tails.
    final srs = _decodeStringAt(data, _decodeUint256(data.sublist(32, 64)).toInt());
    final locationType = _decodeStringAt(data, _decodeUint256(data.sublist(64, 96)).toInt());
    final location = _decodeStringAt(data, _decodeUint256(data.sublist(96, 128)).toInt());
    final recipeType = _decodeStringArrayAt(data, _decodeUint256(data.sublist(128, 160)).toInt());
    final recipePayload = _decodeBytesArrayAt(data, _decodeUint256(data.sublist(160, 192)).toInt());
    final mediaType = _decodeStringArrayAt(data, _decodeUint256(data.sublist(192, 224)).toInt());
    final mediaData = _decodeStringArrayAt(data, _decodeUint256(data.sublist(224, 256)).toInt());
    final memo = _decodeStringAt(data, _decodeUint256(data.sublist(256, 288)).toInt());

    return {
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
      final itemOffset = _decodeUint256(data.sublist(offset + 32 + i * 32, offset + 64 + i * 32)).toInt();
      // Offsets in an array are relative to the array's start word (after count).
      results.add(_decodeStringAt(data, offset + 32 + itemOffset));
    }
    return results;
  }

  static List<String> _decodeBytesArrayAt(Uint8List data, int offset) {
    final count = _decodeUint256(data.sublist(offset, offset + 32)).toInt();
    if (count == 0) return [];

    final results = <String>[];
    for (int i = 0; i < count; i++) {
      final itemOffset = _decodeUint256(data.sublist(offset + 32 + i * 32, offset + 64 + i * 32)).toInt();
      final bytesOffset = offset + 32 + itemOffset;
      final len = _decodeUint256(data.sublist(bytesOffset, bytesOffset + 32)).toInt();
      final rawBytes = data.sublist(bytesOffset + 32, bytesOffset + 32 + len);
      results.add('0x${rawBytes.map((b) => b.toRadixString(16).padLeft(2, "0")).join()}');
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
