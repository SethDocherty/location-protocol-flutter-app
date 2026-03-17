// ignore: depend_on_referenced_packages
import 'package:location_protocol/location_protocol.dart';

/// EAS schema and contract configuration for the Location Protocol app.
///
/// The schema is LP-compliant: the four LP base fields (`lp_version`, `srs`,
/// `location_type`, `location`) are prepended automatically by [SchemaDefinition];
/// the remaining fields are app-specific user fields.
class SchemaConfig {
  /// Default LP version string.
  static const String defaultLpVersion = '1.0.0';

  /// The [SchemaDefinition] for Location Protocol attestations.
  ///
  /// LP base fields are prepended automatically:
  /// `string lp_version, string srs, string location_type, string location`
  ///
  /// User fields follow in declaration order.
  static final SchemaDefinition locationSchema = SchemaDefinition(
    fields: [
      SchemaField(type: 'uint256', name: 'eventTimestamp'),
      SchemaField(type: 'string[]', name: 'recipeType'),
      SchemaField(type: 'bytes[]', name: 'recipePayload'),
      SchemaField(type: 'string[]', name: 'mediaType'),
      SchemaField(type: 'string[]', name: 'mediaData'),
      SchemaField(type: 'string', name: 'memo'),
    ],
    revocable: true,
  );

  /// Full schema string (LP fields + user fields).
  static String get schemaString => locationSchema.toEASSchemaString();

  /// Schema UID on Sepolia (derived from [schemaString]).
  static final String sepoliaSchemaUid = SchemaUID.compute(locationSchema);

  /// EAS contract address on Sepolia (from [ChainConfig]).
  static String get sepoliaContractAddress =>
      ChainConfig.forChainId(sepoliaChainId)!.eas;

  /// Sepolia chain ID.
  static const int sepoliaChainId = 11155111;

  /// EAS EIP-712 domain name (from [EASConstants]).
  static String get domainName => EASConstants.eip712DomainName;

  /// EAS EIP-712 domain version.
  static const String domainVersion = '0.26';

  /// EAS offchain attestation version used by this app.
  static const int easAttestVersion = 1;

  /// Version tag embedded in every signed attestation.
  static const String attestationVersion = 'astral-core-v0.1.0';
}
