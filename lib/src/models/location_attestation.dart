import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import '../eas/abi_encoder.dart';
import '../eas/schema_config.dart';

/// An unsigned location attestation containing all data fields from the
/// EAS Location Protocol schema before signing.
class UnsignedLocationAttestation {
  final int eventTimestamp;
  final String srs;
  final String locationType;
  final String location;
  final List<String> recipeType;
  final List<String> recipePayload;
  final List<String> mediaType;
  final List<String> mediaData;
  final String? memo;
  final String? recipient;
  final int? expirationTime;
  final bool revocable;

  const UnsignedLocationAttestation({
    required this.eventTimestamp,
    required this.srs,
    required this.locationType,
    required this.location,
    required this.recipeType,
    required this.recipePayload,
    required this.mediaType,
    required this.mediaData,
    this.memo,
    this.recipient,
    this.expirationTime,
    this.revocable = true,
  });

  Map<String, dynamic> toJson() => {
        'eventTimestamp': eventTimestamp,
        'srs': srs,
        'locationType': locationType,
        'location': location,
        'recipeType': recipeType,
        'recipePayload': recipePayload,
        'mediaType': mediaType,
        'mediaData': mediaData,
        'memo': memo,
        'recipient': recipient,
        'expirationTime': expirationTime,
        'revocable': revocable,
      };

  factory UnsignedLocationAttestation.fromJson(Map<String, dynamic> json) =>
      UnsignedLocationAttestation(
        eventTimestamp: json['eventTimestamp'] as int,
        srs: json['srs'] as String,
        locationType: json['locationType'] as String,
        location: json['location'] as String,
        recipeType: List<String>.from(json['recipeType'] as List),
        recipePayload: List<String>.from(json['recipePayload'] as List),
        mediaType: List<String>.from(json['mediaType'] as List),
        mediaData: List<String>.from(json['mediaData'] as List),
        memo: json['memo'] as String?,
        recipient: json['recipient'] as String?,
        expirationTime: json['expirationTime'] as int?,
        revocable: json['revocable'] as bool? ?? true,
      );
}

class OffchainLocationAttestation extends UnsignedLocationAttestation {
  final String uid;
  final String signature;
  final String signer;
  final String version;

  const OffchainLocationAttestation({
    required super.eventTimestamp,
    required super.srs,
    required super.locationType,
    required super.location,
    required super.recipeType,
    required super.recipePayload,
    required super.mediaType,
    required super.mediaData,
    super.memo,
    super.recipient,
    super.expirationTime,
    super.revocable,
    required this.uid,
    required this.signature,
    required this.signer,
    required this.version,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'uid': uid,
        'signature': signature,
        'signer': signer,
        'version': version,
      };

  Map<String, dynamic> toEasOffchainJson({
    int chainId = SchemaConfig.sepoliaChainId,
    String contractAddress = SchemaConfig.sepoliaContractAddress,
    String schemaUid = SchemaConfig.sepoliaSchemaUid,
  }) {
    final sigMap = parsedSignature;
    final encodedData = '0x${hex.encode(AbiEncoder.encodeAttestationData(this))}';

    return {
      'sig': {
        'domain': {
          'name': SchemaConfig.domainName,
          'version': SchemaConfig.domainVersion,
          'chainId': chainId.toString(),
          'verifyingContract': contractAddress,
        },
        'primaryType': 'Attest',
        'types': {
          'Attest': [
            {'name': 'version', 'type': 'uint16'},
            {'name': 'schema', 'type': 'bytes32'},
            {'name': 'recipient', 'type': 'address'},
            {'name': 'time', 'type': 'uint64'},
            {'name': 'expirationTime', 'type': 'uint64'},
            {'name': 'revocable', 'type': 'bool'},
            {'name': 'refUID', 'type': 'bytes32'},
            {'name': 'data', 'type': 'bytes'},
          ],
        },
        'signature': {
          'r': sigMap['r'],
          's': sigMap['s'],
          'v': sigMap['v'],
        },
        'uid': uid,
        'message': {
          'version': SchemaConfig.easAttestVersion,
          'schema': schemaUid,
          'recipient': recipient ?? '0x0000000000000000000000000000000000000000',
          'time': eventTimestamp.toString(),
          'expirationTime': (expirationTime ?? 0).toString(),
          'refUID': '0x0000000000000000000000000000000000000000000000000000000000000000',
          'revocable': revocable,
          'data': encodedData,
          'nonce': '0',
        },
      },
      'signer': signer,
    };
  }

  factory OffchainLocationAttestation.fromJson(Map<String, dynamic> json) =>
      OffchainLocationAttestation(
        eventTimestamp: json['eventTimestamp'] as int,
        srs: json['srs'] as String,
        locationType: json['locationType'] as String,
        location: json['location'] as String,
        recipeType: List<String>.from(json['recipeType'] as List),
        recipePayload: List<String>.from(json['recipePayload'] as List),
        mediaType: List<String>.from(json['mediaType'] as List),
        mediaData: List<String>.from(json['mediaData'] as List),
        memo: json['memo'] as String?,
        recipient: json['recipient'] as String?,
        expirationTime: json['expirationTime'] as int?,
        revocable: json['revocable'] as bool? ?? true,
        uid: json['uid'] as String,
        signature: json['signature'] as String,
        signer: json['signer'] as String,
        version: json['version'] as String,
      );

  factory OffchainLocationAttestation.fromEasOffchainJson(Map<String, dynamic> json) {
    final sig = json['sig'] as Map<String, dynamic>;
    final message = sig['message'] as Map<String, dynamic>;
    final signature = sig['signature'] as Map<String, dynamic>;
    final encodedData = message['data'] as String;

    final decoded = AbiEncoder.decodeAttestationData(
      Uint8List.fromList(hex.decode(encodedData.startsWith('0x') ? encodedData.substring(2) : encodedData)),
    );

    return OffchainLocationAttestation(
      eventTimestamp: _parseIntOrString(message['time']),
      srs: decoded['srs'] as String,
      locationType: decoded['locationType'] as String,
      location: decoded['location'] as String,
      recipeType: List<String>.from(decoded['recipeType'] as List),
      recipePayload: List<String>.from(decoded['recipePayload'] as List),
      mediaType: List<String>.from(decoded['mediaType'] as List),
      mediaData: List<String>.from(decoded['mediaData'] as List),
      memo: decoded['memo'] as String?,
      recipient: message['recipient'] as String?,
      expirationTime: message['expirationTime'] != null
          ? _parseIntOrString(message['expirationTime'])
          : null,
      revocable: message['revocable'] as bool? ?? true,
      uid: sig['uid'] as String,
      signature: jsonEncode({
        'v': signature['v'],
        'r': signature['r'],
        's': signature['s'],
      }),
      signer: json['signer'] as String,
      version: SchemaConfig.attestationVersion,
    );
  }

  Map<String, dynamic> get parsedSignature =>
      jsonDecode(signature) as Map<String, dynamic>;

  String toJsonString({bool pretty = false}) {
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(toJson());
    }
    return jsonEncode(toJson());
  }

  String toEasOffchainJsonString({bool pretty = false}) {
    final map = toEasOffchainJson();
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(map);
    }
    return jsonEncode(map);
  }
}

/// Parses a value that may be either an [int] or a [String] representation
/// of an integer (e.g., from EAS JSON where BigInt values are serialized as
/// strings).
int _parseIntOrString(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.parse(value);
  throw FormatException('Expected int or String, got ${value.runtimeType}');
}
