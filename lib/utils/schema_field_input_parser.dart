import 'dart:typed_data';

import 'package:location_protocol/location_protocol.dart';

dynamic parseSchemaFieldInput(SchemaField field, String rawValue) {
  final value = rawValue.trim();

  if (field.type == 'uint256') {
    return BigInt.tryParse(value) ?? BigInt.zero;
  }

  if (field.type == 'bool') {
    return value.toLowerCase() == 'true';
  }

  if (field.type == 'bytes[]') {
    if (value.isEmpty) {
      return <Uint8List>[];
    }

    return value
        .split(',')
        .map((item) => _parseHexBytes(item.trim(), field.name))
        .toList();
  }

  if (field.type.endsWith('[]')) {
    if (value.isEmpty) {
      return <String>[];
    }

    return value.split(',').map((item) => item.trim()).toList();
  }

  return value;
}

Uint8List _parseHexBytes(String value, String fieldName) {
  if (!value.startsWith('0x')) {
    throw FormatException(
      'Field "$fieldName" requires 0x-prefixed hex values.',
    );
  }

  final hex = value.substring(2);
  if (hex.length.isOdd) {
    throw FormatException(
      'Field "$fieldName" contains hex with an odd number of characters.',
    );
  }

  if (hex.isNotEmpty && !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
    throw FormatException(
      'Field "$fieldName" contains invalid hex characters.',
    );
  }

  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}
