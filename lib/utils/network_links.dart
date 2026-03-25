/// Generates block explorer and EAS Scan URLs for supported networks.
class NetworkLinks {
  const NetworkLinks._();

  static const Map<int, String> _easScanDomains = {
    1: 'https://easscan.org',
    10: 'https://optimism.easscan.org',
    8453: 'https://base.easscan.org',
    // ink uses trailing slash in spec but let's standardize on no trailing slash
    57073: 'https://ink.easscan.org',
    42161: 'https://arbitrum.easscan.org',
    42170: 'https://arbitrum-nova.easscan.org',
    137: 'https://polygon.easscan.org',
    534352: 'https://scroll.easscan.org',
    59144: 'https://linea.easscan.org',
    42220: 'https://celo.easscan.org',
    11155111: 'https://sepolia.easscan.org',
    11155420: 'https://optimism-sepolia.easscan.org',
    421614: 'https://arbitrum-sepolia.easscan.org',
    84532: 'https://base-sepolia.easscan.org',
    80002: 'https://polygon-amoy.easscan.org',
    534351: 'https://scroll-sepolia.easscan.org',
    40: 'https://telos.easscan.org',
    1868: 'https://soneium.easscan.org',
  };

  static const Map<int, String> _explorerDomains = {
    1: 'https://etherscan.io',
    10: 'https://optimistic.etherscan.io',
    8453: 'https://basescan.org',
    57073: 'https://explorer.inkonchain.com',
    42161: 'https://arbiscan.io',
    42170: 'https://nova.arbiscan.io',
    137: 'https://polygonscan.com',
    534352: 'https://scrollscan.com',
    59144: 'https://lineascan.build',
    42220: 'https://celoscan.io',
    11155111: 'https://sepolia.etherscan.io',
    11155420: 'https://sepolia-optimism.etherscan.io',
    421614: 'https://sepolia.arbiscan.io',
    84532: 'https://sepolia.basescan.org',
    80002: 'https://amoy.polygonscan.com',
    534351: 'https://sepolia.scrollscan.com',
    40: 'https://teloscan.io',
    1868: 'https://soneium.blockscout.com',
    81457: 'https://blastexplorer.io',
    763373: 'https://explorer-sepolia.inkonchain.com',
    130: 'https://unichain.blockscout.com',
  };

  /// Returns the EAS Scan URL for a specific attestation UID, or null if unsupported.
  static String? getEasScanAttestationUrl(int chainId, String uid) {
    final domain = _easScanDomains[chainId];
    if (domain == null) return null;
    return '$domain/attestation/view/$uid';
  }

  /// Returns the EAS Scan URL for a specific schema UID, or null if unsupported.
  static String? getEasScanSchemaUrl(int chainId, String uid) {
    final domain = _easScanDomains[chainId];
    if (domain == null) return null;
    return '$domain/schema/view/$uid';
  }

  /// Returns the raw EAS Scan base domain for a chain, or null if unsupported.
  /// Used to construct GraphQL endpoints: '${getEasScanDomain(chainId)}/graphql'.
  static String? getEasScanDomain(int chainId) => _easScanDomains[chainId];

  /// Returns the Block Explorer URL for a specific transaction hash, or null if unsupported.
  static String? getExplorerTxUrl(int chainId, String txHash) {
    final domain = _explorerDomains[chainId];
    if (domain == null) return null;
    return '$domain/tx/$txHash';
  }
}
