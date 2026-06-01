import 'dart:convert';

import 'package:location_protocol/location_protocol.dart';

Map<String, dynamic> signedOffchainAttestationToJsonMap(
  SignedOffchainAttestation attestation,
) {
  final canonical = attestation.toJson();
  return _stringKeyedMap(_jsonSafeValue(canonical) as Map);
}

String encodeSignedOffchainAttestationJson(
  SignedOffchainAttestation attestation, {
  bool pretty = true,
}) {
  final map = signedOffchainAttestationToJsonMap(attestation);
  if (pretty) {
    return const JsonEncoder.withIndent('  ').convert(map);
  }
  return jsonEncode(map);
}

SignedOffchainAttestation decodeSignedOffchainAttestationJson(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON object.',
    );
  }

  final map = _stringKeyedMap(decoded);
  return signedOffchainAttestationFromJsonMap(map);
}

SignedOffchainAttestation signedOffchainAttestationFromJsonMap(
  Map<String, dynamic> map,
) {
  final normalized = _normalizeSignedOffchainAttestationInputMap(map);

  _validateCanonicalEnvelope(normalized);

  try {
    return SignedOffchainAttestation.fromJson(normalized);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON with top-level signer and nested sig.',
    );
  }
}

void _validateCanonicalEnvelope(Map<String, dynamic> map) {
  if (!_hasExactKeys(map, const {'signer', 'sig'}) || map['signer'] is! String) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON with top-level signer and nested sig.',
    );
  }

  final sig = map['sig'];
  if (sig is! Map<String, dynamic> ||
      !_hasExactKeys(sig, const {
        'domain',
        'primaryType',
        'types',
        'message',
        'signature',
        'uid',
      })) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON with canonical sig envelope.',
    );
  }

  if (sig['primaryType'] != 'Attest' || sig['uid'] is! String) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON with Attest primary type and uid.',
    );
  }

  final domain = sig['domain'];
  final types = sig['types'];
  final message = sig['message'];
  final signature = sig['signature'];

  if (domain is! Map<String, dynamic> ||
      types is! Map<String, dynamic> ||
      message is! Map<String, dynamic> ||
      signature is! Map<String, dynamic>) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON with object-valued domain, types, message, and signature.',
    );
  }

  if (!_hasExactKeys(signature, const {'v', 'r', 's'}) ||
      signature['v'] is! int ||
      signature['r'] is! String ||
      signature['s'] is! String) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON signature fields v, r, and s.',
    );
  }

  if (!_hasExactKeys(types, const {'EIP712Domain', 'Attest'}) ||
      types['EIP712Domain'] is! List ||
      types['Attest'] is! List) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON to preserve EIP712Domain and Attest types.',
    );
  }

  _validateTypeFields(types['EIP712Domain'] as List, 'EIP712Domain');
  _validateTypeFields(types['Attest'] as List, 'Attest');

  if (!_hasExactKeys(domain, const {
        'name',
        'version',
        'chainId',
        'verifyingContract',
      }) ||
      domain['name'] is! String ||
      domain['version'] is! String ||
      domain['chainId'] is! int ||
      domain['verifyingContract'] is! String) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON domain scalar fields name, version, chainId, and verifyingContract.',
    );
  }

  const requiredMessageKeys = {
    'version',
    'schema',
    'recipient',
    'time',
    'expirationTime',
    'revocable',
    'refUID',
    'data',
    'salt',
  };

  if (!_hasExactKeys(message, requiredMessageKeys)) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON message fields for the EAS offchain envelope.',
    );
  }

  if (message['version'] is! int ||
      message['schema'] is! String ||
      message['recipient'] is! String ||
      message['time'] is! int ||
      message['expirationTime'] is! int ||
      message['revocable'] is! bool ||
      message['refUID'] is! String ||
      message['data'] is! String ||
      message['salt'] is! String) {
    throw const FormatException(
      'Expected canonical EAS offchain attestation JSON message scalar fields to use canonical JSON types.',
    );
  }
}

void _validateTypeFields(List<dynamic> fields, String typeName) {
  for (final field in fields) {
    if (field is! Map<String, dynamic> ||
        !_hasExactKeys(field, const {'name', 'type'}) ||
        field['name'] is! String ||
        field['type'] is! String) {
      throw FormatException(
        'Expected canonical EAS offchain attestation JSON $typeName entries to contain string name/type fields.',
      );
    }
  }
}

bool _hasExactKeys(Map<String, dynamic> map, Set<String> keys) {
  return map.length == keys.length && map.keys.toSet().containsAll(keys);
}

Map<String, dynamic> _normalizeSignedOffchainAttestationInputMap(
  Map<String, dynamic> map,
) {
  final normalized = _stringKeyedMap(map);
  final sig = normalized['sig'];

  if (sig is! Map<String, dynamic>) {
    return normalized;
  }

  final message = sig['message'];
  if (message is! Map<String, dynamic>) {
    return normalized;
  }

  for (final key in const ['version', 'time', 'expirationTime']) {
    final value = message[key];
    if (value is BigInt) {
      message[key] = value.toInt();
    }
  }

  return normalized;
}

Map<String, dynamic> _stringKeyedMap(Map map) {
  return Map<String, dynamic>.fromEntries(
    map.entries.map(
      (entry) => MapEntry(
        entry.key.toString(),
        _stringKeyedValue(entry.value),
      ),
    ),
  );
}

dynamic _stringKeyedValue(dynamic value) {
  if (value is Map) {
    return _stringKeyedMap(value);
  }
  if (value is List) {
    return value.map(_stringKeyedValue).toList();
  }
  return value;
}

dynamic _jsonSafeValue(dynamic value, [String? parentKey]) {
  if (value is BigInt) {
    if (parentKey == 'time' ||
        parentKey == 'expirationTime' ||
        parentKey == 'version') {
      return value.toInt();
    }
    return value.toString();
  }
  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(
        key,
        _jsonSafeValue(nestedValue, key.toString()),
      ),
    );
  }
  if (value is List) {
    return value.map((item) => _jsonSafeValue(item, parentKey)).toList();
  }
  return value;
}
