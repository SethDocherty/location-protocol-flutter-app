import 'dart:convert';
import 'dart:typed_data';

import 'package:web3dart/crypto.dart' as eth_crypto;

import '../models/location_attestation.dart';

/// Implements Solidity ABI encoding for the Location Protocol EAS schema:
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
  ///
  /// Layout:
  /// ```
  /// count (32 bytes)
  /// offset[0] (32 bytes)  <- relative to start of content area (after count)
  /// ...
  /// offset[n-1] (32 bytes)
  /// tail[0] = uint256(len) ++ right_pad_32(utf8_bytes)
  /// ...
  /// tail[n-1]
  /// ```
  static Uint8List encodeStringArray(List<String> arr) {
    final count = encodeUint256(BigInt.from(arr.length));
    if (arr.isEmpty) return count;

    final tails = arr.map(encodeStringTail).toList();
    return _encodeArrayWithTails(count, tails);
  }

  /// Encodes a `bytes[]` value.
  ///
  /// Each element string is treated as a hex-encoded byte sequence
  /// (with or without leading "0x"). An empty string encodes as zero bytes.
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
  ///
  /// The 9 fields have these ABI types:
  ///   uint256, string, string, string, string[], bytes[], string[], string[], string
  ///
  /// Static fields are written in-place; dynamic fields use offset pointers.
  /// The head section is always 9 × 32 = 288 bytes.
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
  /// Exposed separately to make unit-testing easier.
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
    // 9 fields — head is always 9 * 32 = 288 bytes.
    const headSize = 9 * 32;

    // Encode the 8 dynamic field tails in schema order.
    final tailSrs = encodeStringTail(srs);
    final tailLocationType = encodeStringTail(locationType);
    final tailLocation = encodeStringTail(location);
    final tailRecipeType = encodeStringArray(recipeType);
    final tailRecipePayload = encodeBytesArray(recipePayload);
    final tailMediaType = encodeStringArray(mediaType);
    final tailMediaData = encodeStringArray(mediaData);
    final tailMemo = encodeStringTail(memo);

    final dynamicTails = [
      tailSrs,
      tailLocationType,
      tailLocation,
      tailRecipeType,
      tailRecipePayload,
      tailMediaType,
      tailMediaData,
      tailMemo,
    ];

    // Compute offsets for each dynamic field (absolute from byte 0).
    final offsets = <int>[];
    var offset = headSize;
    for (final tail in dynamicTails) {
      offsets.add(offset);
      offset += tail.length;
    }

    // Build the head: static field value first, then 8 offsets.
    final head = _concat([
      encodeUint256(BigInt.from(eventTimestamp)),
      ...offsets.map((o) => encodeUint256(BigInt.from(o))),
    ]);

    return _concat([head, ...dynamicTails]);
  }

  /// Computes keccak256 of the ABI-encoded attestation data.
  static Uint8List hashAttestationData(
          UnsignedLocationAttestation attestation) =>
      eth_crypto.keccak256(encodeAttestationData(attestation));

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Uint8List _encodeArrayWithTails(
      Uint8List countWord, List<Uint8List> tails) {
    // Offsets are relative to the start of the *content area* (word after count).
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
