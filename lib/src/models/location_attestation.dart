import 'dart:convert';

/// An unsigned location attestation containing all data fields from the
/// EAS Location Protocol schema before signing.
class UnsignedLocationAttestation {
  /// Unix timestamp in seconds of when the event occurred.
  final int eventTimestamp;

  /// Spatial reference system, e.g. "EPSG:4326" (WGS84).
  final String srs;

  /// Type descriptor for the location field, e.g. "geojson-point".
  final String locationType;

  /// Location data as a JSON string, e.g.
  /// '{"type":"Point","coordinates":[-122.4194,37.7749]}'.
  final String location;

  /// Recipe types used to create this attestation. Empty for v0.1.
  final List<String> recipeType;

  /// Recipe payloads (hex-encoded bytes). Empty for v0.1.
  final List<String> recipePayload;

  /// MIME types for any attached media, e.g. ["image/png"].
  final List<String> mediaType;

  /// Media data URIs, e.g. ["ipfs://Qm..."].
  final List<String> mediaData;

  /// Optional human-readable memo.
  final String? memo;

  /// Ethereum address of the intended recipient. Defaults to zero address.
  final String? recipient;

  /// Unix timestamp of expiration. 0 means no expiration.
  final int? expirationTime;

  /// Whether the attestation can be revoked.
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

/// A signed offchain location attestation produced by the EIP-712 signing flow.
class OffchainLocationAttestation extends UnsignedLocationAttestation {
  /// Unique identifier: keccak256 of the EIP-712 digest, 0x-prefixed.
  final String uid;

  /// Compact JSON signature: {"v":28,"r":"0x...","s":"0x..."}.
  final String signature;

  /// Ethereum address of the signer, 0x-prefixed, EIP-55 checksum.
  final String signer;

  /// Version string, e.g. "astral-core-v0.1.0".
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

  /// Deserialises the [signature] field back into its v/r/s components.
  Map<String, dynamic> get parsedSignature =>
      jsonDecode(signature) as Map<String, dynamic>;

  String toJsonString({bool pretty = false}) {
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(toJson());
    }
    return jsonEncode(toJson());
  }
}
