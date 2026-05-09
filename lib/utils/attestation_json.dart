import 'dart:convert';
import 'dart:typed_data';

import 'package:location_protocol/location_protocol.dart';

Map<String, dynamic> signedOffchainAttestationToJsonMap(
  SignedOffchainAttestation attestation,
) {
  return {
    'uid': attestation.uid,
    'schemaUID': attestation.schemaUID,
    'recipient': attestation.recipient,
    'time': attestation.time.toInt(),
    'expirationTime': attestation.expirationTime.toInt(),
    'revocable': attestation.revocable,
    'refUID': attestation.refUID,
    'data': _bytesToHex(attestation.data),
    'salt': attestation.salt,
    'version': attestation.version,
    'signature': {
      'v': attestation.signature.v,
      'r': attestation.signature.r,
      's': attestation.signature.s,
    },
    'signer': attestation.signer,
  };
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
  final map = jsonDecode(jsonText) as Map<String, dynamic>;
  return signedOffchainAttestationFromJsonMap(map);
}

SignedOffchainAttestation signedOffchainAttestationFromJsonMap(
  Map<String, dynamic> map,
) {
  final sigMap = Map<String, dynamic>.from(map['signature'] as Map);

  return SignedOffchainAttestation(
    uid: map['uid'] as String,
    schemaUID: map['schemaUID'] as String,
    recipient: map['recipient'] as String,
    time: BigInt.from(map['time'] as int),
    expirationTime: BigInt.from(map['expirationTime'] as int),
    revocable: map['revocable'] as bool,
    refUID: map['refUID'] as String,
    data: _hexToBytes(map['data'] as String),
    salt: map['salt'] as String,
    version: map['version'] as int,
    signature: EIP712Signature(
      v: sigMap['v'] as int,
      r: sigMap['r'] as String,
      s: sigMap['s'] as String,
    ),
    signer: map['signer'] as String,
  );
}

String _bytesToHex(Uint8List bytes) {
  return '0x${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
}

Uint8List _hexToBytes(String hexValue) {
  final normalized = hexValue.startsWith('0x')
      ? hexValue.substring(2)
      : hexValue;
  return Uint8List.fromList([
    for (var i = 0; i < normalized.length; i += 2)
      int.parse(normalized.substring(i, i + 2), radix: 16),
  ]);
}
