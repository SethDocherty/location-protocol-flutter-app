/// EAS schema and contract addresses for the Location Protocol.
class SchemaConfig {
  /// The EAS schema string for location attestations.
  static const String schemaString =
      'uint256 eventTimestamp,string srs,string locationType,string location,'
      'string[] recipeType,bytes[] recipePayload,string[] mediaType,'
      'string[] mediaData,string memo';

  /// Schema UID on Sepolia.
  static const String sepoliaSchemaUid =
      '0xba4171c92572b1e4f241d044c32cdf083be9fd946b8766977558ca6378c824e2';

  /// EAS contract address on Sepolia.
  static const String sepoliaContractAddress =
      '0xC2679fBD37d54388Ce493F1DB75320D236e1815e';

  /// Sepolia chain ID.
  static const int sepoliaChainId = 11155111;

  /// EAS domain name and version for standard compatibility.
  static const String domainName = 'EAS Attestation';
  static const String domainVersion = '0.26';

  /// EAS offchain attestation version (1 matches the official example).
  static const int easAttestVersion = 1;

  /// Version tag embedded in our internal models.
  static const String attestationVersion = 'astral-core-v0.1.0';
}
