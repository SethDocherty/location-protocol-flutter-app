import 'package:flutter/material.dart';

import '../src/eas/attestation_signer.dart';
import '../src/eas/external_sign_dialog.dart';
import '../src/eas/external_wallet_signer.dart';
import '../src/eas/private_key_import_dialog.dart';
import '../src/eas/privy_signer_adapter.dart';
import '../src/privy_auth_modal/privy_auth_modal.dart';
import 'sign_screen.dart';
import 'verify_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = PrivyAuthProvider.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Protocol'),
        centerTitle: true,
        actions: [
          if (auth.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                try {
                  await PrivyAuthProvider.of(context).logout();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Logged out')),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Logout error: $e')),
                  );
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: !auth.isReady
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTitleCard(context, auth, theme),
                    const SizedBox(height: 32),
                    if (!auth.isAuthenticated) ...[
                      _buildLoginButton(context),
                      const SizedBox(height: 32),
                    ],
                    if (auth.isAuthenticated) ...[
                      _NavButton(
                        icon: Icons.edit_note,
                        label: 'Sign Attestation',
                        subtitle: 'Build and sign a location attestation',
                        onTap: () {
                          final wallet = auth.wallet;
                          final walletAddress = auth.walletAddress;

                          if (wallet == null && walletAddress == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No wallet available. Please try logging in again.',
                                ),
                              ),
                            );
                            return;
                          }

                          // Choose signer: embedded wallet (Privy RPC) or
                          // external wallet (copy/paste MetaMask console flow).
                          final AttestationSigner signer = wallet != null
                              ? PrivySignerAdapter.fromWallet(wallet)
                              : ExternalWalletSigner(
                                  address: walletAddress!,
                                  onSignRequest: (addr, jsonTypedData) =>
                                      showExternalSignDialog(
                                        context,
                                        walletAddress: addr,
                                        jsonTypedData: jsonTypedData,
                                      ),
                                );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SignScreen(signer: signer),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    // ── Always available (no Privy auth required) ─────────────
                    if (auth.isAuthenticated) const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(),
                    ),
                    _NavButton(
                      icon: Icons.verified_user_outlined,
                      label: 'Verify Attestation',
                      subtitle: 'Paste a signed attestation and verify it',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VerifyScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _NavButton(
                      icon: Icons.key,
                      label: 'Sign with Private Key',
                      subtitle: 'Import a key for one-time in-memory signing',
                      onTap: () async {
                        final signer =
                            await showPrivateKeyImportDialog(context);
                        if (signer == null || !context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SignScreen(signer: signer),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTitleCard(
    BuildContext context,
    PrivyAuthState auth,
    ThemeData theme,
  ) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.location_on, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'Location Protocol\nSignature Service',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            if (auth.isAuthenticated && auth.walletAddress != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              Text(
                'Wallet',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer
                      .withValues(alpha: 0.7),
                ),
              ),
              Text(
                auth.walletAddress!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        icon: const Icon(Icons.login),
        label: const Text('Log In'),
        onPressed: () => showPrivyLoginModal(context),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
