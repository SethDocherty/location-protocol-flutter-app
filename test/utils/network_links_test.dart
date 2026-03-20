import 'package:flutter_test/flutter_test.dart';
import 'package:location_protocol_flutter_app/utils/network_links.dart';

void main() {
  group('NetworkLinks', () {
    test('getEasScanAttestationUrl returns valid url for Sepolia', () {
      expect(
        NetworkLinks.getEasScanAttestationUrl(11155111, '0xabc'),
        'https://sepolia.easscan.org/attestation/view/0xabc',
      );
    });

    test('getEasScanAttestationUrl returns null for Blast', () {
      expect(NetworkLinks.getEasScanAttestationUrl(81457, '0xabc'), isNull);
    });

    test('getExplorerTxUrl returns valid url for Base', () {
      expect(
        NetworkLinks.getExplorerTxUrl(8453, '0xdef'),
        'https://basescan.org/tx/0xdef',
      );
    });

    test('getExplorerTxUrl returns null for unknown chain', () {
      expect(NetworkLinks.getExplorerTxUrl(999999, '0xdef'), isNull);
    });
  });
}
