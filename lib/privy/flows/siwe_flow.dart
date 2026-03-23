/// Sign In With Ethereum (SIWE) authentication flow.
///
/// unified seamless SIWE flow using ReownAppKit to connect and sign.
library;

import 'package:flutter/material.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:on_chain/on_chain.dart';
import '../privy_auth_config.dart';
import '../privy_manager.dart';
import '../../services/reown_service.dart';

/// SIWE login flow — automatic connection and signature request via WalletConnect.
class SiweFlow extends StatefulWidget {
  /// Called with null on success, or a String error.
  final void Function(String? error) onComplete;

  /// Called when the user taps back to return to method selector.
  final VoidCallback onBack;

  /// Auth config supplying siweAppDomain / siweAppUri.
  final PrivyAuthConfig config;

  const SiweFlow({
    super.key,
    required this.onComplete,
    required this.onBack,
    required this.config,
  });

  @override
  State<SiweFlow> createState() => _SiweFlowState();
}

class _SiweFlowState extends State<SiweFlow> {
  final ReownService _reownService = ReownService();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reownService.initialize(context);
  }

  Future<void> _loginWithExternalWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final address = await _reownService.connectAndGetAddress();
      if (address == null || address.isEmpty) {
        setState(() {
          _error = 'External wallet connection failed or cancelled.';
          _loading = false;
        });
        return;
      }
      
      // EIP-4361 strictly requires an EIP-55 checksummed address.
      // WalletConnect returns lowercase, so we checksum it using blockchain_utils.
      final checksummedAddress = ETHAddress(address).address;

      final params = SiweMessageParams(
        appDomain: widget.config.siweAppDomain,
        appUri: widget.config.siweAppUri,
        chainId: _reownService.currentChainId,
        walletAddress: checksummedAddress,
      );

      final generateResult = await PrivyManager().privy.siwe.generateSiweMessage(params);
      
      String siweMessage = '';
      bool hasError = false;
      generateResult.fold(
        onSuccess: (message) => siweMessage = message,
        onFailure: (error) {
          hasError = true;
          setState(() {
            _error = error.message;
            _loading = false;
          });
        },
      );
      if (hasError) return;

      if (!mounted) return;
      final signature = await _reownService.personalSign(context, siweMessage);

      // Reown appKitModal returns signature as hex string with 0x prefix correctly
      final loginResult = await PrivyManager().privy.siwe.loginWithSiwe(
        message: siweMessage,
        signature: signature,
        params: params,
        metadata: const WalletLoginMetadata(walletClientType: WalletClientType.metamask),
      );

      loginResult.fold(
        onSuccess: (_) => widget.onComplete(null),
        onFailure: (error) {
          setState(() {
            _error = error.message;
            _loading = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Back / title row
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _loading ? null : widget.onBack,
            ),
            Expanded(
              child: Text(
                'Connect Wallet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildUnifiedStep(),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildUnifiedStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sign in with your external wallet to securely authenticate.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _loginWithExternalWallet,
          icon: _loading 
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
              : const Icon(Icons.account_balance_wallet),
          label: const Text('Connect & Sign In'),
        ),
      ],
    );
  }
}
