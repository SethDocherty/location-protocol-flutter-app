import 'package:flutter/material.dart';

import '../src/eas/privy_wallet_signer.dart';
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
                    if (!auth.isAuthenticated)
                      _buildLoginButton(context)
                    else ...[
                      _NavButton(
                        icon: Icons.edit_note,
                        label: 'Sign Attestation',
                        subtitle: 'Build and sign a location attestation',
                        onTap: () {
                          final wallet = auth.wallet;
                          if (wallet == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No wallet available. Please try logging in again.',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SignScreen(
                                signer: PrivyWalletSigner(wallet),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _NavButton(
                        icon: Icons.verified_user,
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
                    ],
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
            if (auth.isAuthenticated && auth.wallet != null) ...[
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
                auth.wallet!.address,
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
