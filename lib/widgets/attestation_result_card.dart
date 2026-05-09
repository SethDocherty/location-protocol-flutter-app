import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:location_protocol/location_protocol.dart';

import '../utils/attestation_json.dart';

/// Displays the result of a signed offchain attestation.
class AttestationResultCard extends StatelessWidget {
  final SignedOffchainAttestation attestation;

  const AttestationResultCard({super.key, required this.attestation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attestation Signed', style: theme.textTheme.titleLarge),
            const Divider(),
            _row('UID', attestation.uid),
            _row('Signer', attestation.signer),
            _row('Schema UID', attestation.schemaUID),
            _row(
              'Time',
              DateTime.fromMillisecondsSinceEpoch(
                attestation.time.toInt() * 1000,
              ).toIso8601String(),
            ),
            _row('Version', attestation.version.toString()),
            _row('Salt', attestation.salt),
            const Divider(),
            Text('Signature', style: theme.textTheme.titleSmall),
            _row('v', attestation.signature.v.toString()),
            _row('r', attestation.signature.r),
            _row('s', attestation.signature.s),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _copyToClipboard(context),
                icon: const Icon(Icons.copy),
                label: const Text('Copy Full Result'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final text = encodeSignedOffchainAttestationJson(attestation);

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attestation copied to clipboard as JSON')),
    );
  }
}
