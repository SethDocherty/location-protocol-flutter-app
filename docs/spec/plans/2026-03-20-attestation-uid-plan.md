# Attestation UID Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wait for EVM transaction receipts to extract and display the EAS Attestation UID along with dynamic block explorer URLs.

**Architecture:** 
1. Create a `NetworkLinks` utility to generate block explorer and EAS Scan URLs across various chains. 
2. Add `waitForAttestationUid` to `AttestationService` to poll for the transaction receipt and parse the `Attested` event log. 
3. Wire the logic into `OnchainAttestScreen` so the user sees real-time progress, the generated UID, and chain-aware outgoing links.

**Tech Stack:** Dart, Flutter, Privy SDK, EAS

---

### Task 1: Network Links Utility

**Files:**
- Create: `lib/utils/network_links.dart`
- Create: `test/utils/network_links_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/utils/network_links_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/network_links_test.dart`
Expected: FAIL since the file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/utils/network_links.dart

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

  /// Returns the Block Explorer URL for a specific transaction hash, or null if unsupported.
  static String? getExplorerTxUrl(int chainId, String txHash) {
    final domain = _explorerDomains[chainId];
    if (domain == null) return null;
    return '$domain/tx/$txHash';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/utils/network_links_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add test/utils/network_links_test.dart lib/utils/network_links.dart
git commit -m "feat: add NetworkLinks utility for EAS and block explorer URLs"
```

---

### Task 2: Polling for Attestation UID

**Files:**
- Modify: `lib/protocol/attestation_service.dart:148-155` (Around the RPC check area)
- Modify: `test/protocol/attestation_service_test.dart`

- [ ] **Step 1: Write the failing test**

Add to `test/protocol/attestation_service_test.dart` at the end of the `AttestationService — RPC checks` group:

```dart
    test('waitForAttestationUid polls and returns uid', () async {
      int pollCount = 0;
      privySigner = PrivySigner(
        walletAddress: '0x123',
        rpcCaller: (method, params) async {
          if (method == 'eth_getTransactionReceipt') {
            pollCount++;
            if (pollCount < 2) return 'null';
            // Return receipt on second poll, returning the UID in data
            return '''
            {
              "logs": [
                {
                  "address": "${rpcService.easAddress}",
                  "data": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
                }
              ]
            }
            ''';
          }
          return 'null';
        },
      );
      rpcService = AttestationService(signer: privySigner, chainId: 11155111);

      final uid = await rpcService.waitForAttestationUid(
        '0xtx',
        pollInterval: const Duration(milliseconds: 1), // Fast for tests
      );

      expect(pollCount, 2);
      expect(uid, '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    });

    test('waitForAttestationUid throws if no logs match', () async {
      privySigner = PrivySigner(
        walletAddress: '0x123',
        rpcCaller: (method, params) async {
          if (method == 'eth_getTransactionReceipt') {
            return '{"logs": []}';
          }
          return 'null';
        },
      );
      rpcService = AttestationService(signer: privySigner, chainId: 11155111);

      expect(
        () => rpcService.waitForAttestationUid(
          '0xtx',
          pollInterval: const Duration(milliseconds: 1),
        ),
        throwsException,
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/protocol/attestation_service_test.dart`
Expected: FAIL due to missing `waitForAttestationUid` method.

- [ ] **Step 3: Write minimal implementation**

Add to `AttestationService` in `lib/protocol/attestation_service.dart`:

```dart
  /// Polls for a transaction receipt and extracts the EAS Attestation UID.
  Future<String> waitForAttestationUid(
    String txHash, {
    int maxRetries = 15,
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
        final receipt = await getTransactionReceipt(txHash);
        if (receipt != null) {
            final logs = receipt['logs'] as List<dynamic>?;
            if (logs != null) {
              for (final logRaw in logs) {
                final log = logRaw as Map<String, dynamic>;
                final address = log['address'] as String?;
                if (address != null && address.toLowerCase() == _easAddress.toLowerCase()) {
                  final data = log['data'] as String?;
                  if (data != null && data.length >= 66) {
                    return data.substring(0, 66);
                  }
                }
              }
            }
            throw Exception('Transaction mined but no Attested event found.');
        }
        await Future.delayed(pollInterval);
    }
    throw Exception('Timeout waiting for transaction receipt.');
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/protocol/attestation_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/protocol/attestation_service.dart test/protocol/attestation_service_test.dart
git commit -m "feat: add waitForAttestationUid polling utility"
```

---

### Task 3: Integrating the UI

**Files:**
- Modify: `lib/screens/onchain_attest_screen.dart:25-214`

- [ ] **Step 1: Write the minimal implementation**

We will update the submission function and the render view in `lib/screens/onchain_attest_screen.dart`. Since UI tests are currently light or absent, we proceed with the direct modification.

Replace `_OnchainAttestScreenState` starting at `_txHash`:

```dart
  String? _txHash;
  String? _uid;
  String? _error;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!mounted) return;
    setState(() {
      _submitting = true;
      _txHash = null;
      _uid = null;
      _error = null;
    });

    try {
      final lat = double.parse(_latController.text.trim());
      final lng = double.parse(_lngController.text.trim());
      final memo = _memoController.text.trim();

      // Build calldata
      final callData = widget.service.buildAttestCallData(
        lat: lat,
        lng: lng,
        memo: memo.isEmpty ? 'No memo' : memo,
      );

      // Build tx request
      final txRequest = widget.service.buildTxRequest(
        callData: callData,
        contractAddress: widget.service.easAddress,
      );

      // Send via Privy wallet
      final result = await widget.wallet.provider.request(
        EthereumRpcRequest(method: 'eth_sendTransaction', params: [jsonEncode(txRequest)]),
      );

      String? hash;
      result.fold(
        onSuccess: (r) => hash = r.data,
        onFailure: (e) => throw Exception('Transaction failed: ${e.message}'),
      );

      if (hash != null) {
        if (mounted) setState(() => _txHash = hash);
        
        // Wait for the UID
        final uid = await widget.service.waitForAttestationUid(hash!);
        if (mounted) setState(() => _uid = uid);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
```

Update the imports block at the top of the file to include our new networking tool:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // We should probably use this to launch links. If it's not installed, we can fall back to SnackBar or just the SnackBar. Wait, the user has a SnackBar implementation currently.

import '../protocol/attestation_service.dart';
import '../utils/network_links.dart';
```

And swap the bottom Card view where `_txHash` was displayed:

```dart
            if (_txHash != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transaction Submitted',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        'TX Hash: $_txHash',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      if (_uid != null) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          'Attestation UID: $_uid',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Waiting for transaction to be mined...'),
                          ]
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (NetworkLinks.getExplorerTxUrl(widget.service.chainId, _txHash!) != null)
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('View at: ${NetworkLinks.getExplorerTxUrl(widget.service.chainId, _txHash!)}'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Block Explorer'),
                            ),
                          if (_uid != null && NetworkLinks.getEasScanAttestationUrl(widget.service.chainId, _uid!) != null)
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('View at: ${NetworkLinks.getEasScanAttestationUrl(widget.service.chainId, _uid!)}'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('EAS Scan'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
```

IMPORTANT: Ensure `_explorerUrl` is deleted from the `_OnchainAttestScreenState` as we no longer need it.

- [ ] **Step 2: Start the application**
Run: `flutter test` or manually use the Android emulator to ensure the Attestation screen operates efficiently.
Expected: The UI should correctly render intermediate and final states. Because we have no specific automated test for this component's dynamic behaviors, manual verification via `flutter analyze` or unit test runs counts as validation.

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onchain_attest_screen.dart
git commit -m "feat: display Attestation UID and dynamic explorer links in UI"
```
