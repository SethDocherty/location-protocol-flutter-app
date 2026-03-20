import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';

import '../privy/privy_module.dart';
import '../protocol/protocol_module.dart';
import '../widgets/private_key_import_dialog.dart';
import '../widgets/external_sign_dialog.dart';
import 'sign_screen.dart';
import 'verify_screen.dart';
import 'onchain_attest_screen.dart';
import 'register_schema_screen.dart';
import 'timestamp_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/settings_service.dart';

/// Main screen — auth-gated navigation hub for all attestation operations.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _chainId = 11155111; // default until settings load

  @override
  void initState() {
    super.initState();
    _loadChainId();
  }

  Future<void> _loadChainId() async {
    final settings = await SettingsService.create();
    if (mounted) setState(() => _chainId = settings.selectedChainId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = PrivyAuthProvider.of(context);

    if (!auth.isReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Location Protocol')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Protocol'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              // Reload chainId in case the user changed it in Settings.
              if (mounted) _loadChainId();
            },
          ),
          if (auth.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => auth.logout(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (auth.isAuthenticated && auth.walletAddress != null) ...[
              _WalletCard(address: auth.walletAddress!),
              const SizedBox(height: 16),
            ],

            if (!auth.isAuthenticated) ...[
              _buildLoginButton(context),
              const SizedBox(height: 12),
            ],

            // --- Always available ---
            _SectionHeader('Offchain Operations'),
            _buildPrivateKeySignButton(context),
            const SizedBox(height: 8),
            _buildVerifyButton(context),
            const SizedBox(height: 8),

            // --- Auth-gated ---
            if (auth.isAuthenticated) ...[
              _buildSignWithWalletButton(context, auth),
              const SizedBox(height: 8),
              _buildExternalWalletSignButton(context, auth),
              const SizedBox(height: 24),

              _SectionHeader('Onchain Operations'),
              _buildOnchainAttestButton(context, auth),
              const SizedBox(height: 8),
              _buildRegisterSchemaButton(context, auth),
              const SizedBox(height: 8),
              _buildTimestampButton(context, auth),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => showPrivyLoginModal(context),
      icon: const Icon(Icons.login),
      label: const Text('Login with Privy'),
    );
  }

  Widget _buildSignWithWalletButton(BuildContext context, PrivyAuthState auth) {
    return _ActionButton(
      icon: Icons.edit_note,
      label: 'Sign with Embedded Wallet',
      onPressed: () {
        if (auth.wallet == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No embedded wallet available')),
          );
          return;
        }
        final signer = PrivySigner.fromWallet(auth.wallet!);
        final service = AttestationService(signer: signer, chainId: _chainId);
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => SignScreen(service: service)));
      },
    );
  }

  Widget _buildExternalWalletSignButton(
    BuildContext context,
    PrivyAuthState auth,
  ) {
    return _ActionButton(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Sign with External Wallet',
      onPressed: () {
        if (auth.walletAddress == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No wallet address available')),
          );
          return;
        }
        final signer = ExternalWalletSigner(
          walletAddress: auth.walletAddress!,
          onSignTypedData: (typedData) async {
            final sig = await showExternalSignDialog(context, typedData);
            if (sig == null) throw Exception('Signing cancelled');
            return sig;
          },
        );
        final service = AttestationService(signer: signer, chainId: _chainId);
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => SignScreen(service: service)));
      },
    );
  }

  Widget _buildPrivateKeySignButton(BuildContext context) {
    return _ActionButton(
      icon: Icons.key,
      label: 'Sign with Private Key',
      onPressed: () async {
        final key = await showPrivateKeyImportDialog(context);
        if (key == null || !context.mounted) return;
        final signer = LocalKeySigner(privateKeyHex: key);
        final service = AttestationService(signer: signer, chainId: _chainId);
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SignScreen(service: service)),
          );
        }
      },
    );
  }

  Widget _buildVerifyButton(BuildContext context) {
    // Create a dummy service for verification (signer not used for verify)
    return _ActionButton(
      icon: Icons.verified,
      label: 'Verify Attestation',
      onPressed: () {
        // For verify, we need a service but the signer doesn't matter.
        // Use a throwaway LocalKeySigner — verify doesn't sign anything.
        final dummySigner = LocalKeySigner(
          privateKeyHex:
              'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
        );
        final service = AttestationService(
          signer: dummySigner,
          chainId: _chainId,
        );
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VerifyScreen(service: service)),
        );
      },
    );
  }

  Widget _buildOnchainAttestButton(BuildContext context, PrivyAuthState auth) {
    return _ActionButton(
      icon: Icons.cloud_upload,
      label: 'Attest Onchain',
      onPressed: () {
        if (auth.wallet == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Onchain operations require an embedded wallet'),
            ),
          );
          return;
        }
        final signer = PrivySigner.fromWallet(auth.wallet!);
        final service = AttestationService(signer: signer, chainId: _chainId);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                OnchainAttestScreen(service: service, wallet: auth.wallet!),
          ),
        );
      },
    );
  }

  Widget _buildRegisterSchemaButton(BuildContext context, PrivyAuthState auth) {
    return _ActionButton(
      icon: Icons.app_registration,
      label: 'Register Schema',
      onPressed: () {
        if (auth.wallet == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Schema registration requires an embedded wallet'),
            ),
          );
          return;
        }
        final signer = PrivySigner.fromWallet(auth.wallet!);
        final service = AttestationService(signer: signer, chainId: _chainId);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                RegisterSchemaScreen(service: service, wallet: auth.wallet!),
          ),
        );
      },
    );
  }

  Widget _buildTimestampButton(BuildContext context, PrivyAuthState auth) {
    return _ActionButton(
      icon: Icons.access_time,
      label: 'Timestamp Offchain UID',
      onPressed: () {
        if (auth.wallet == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Timestamping requires an embedded wallet'),
            ),
          );
          return;
        }
        final signer = PrivySigner.fromWallet(auth.wallet!);
        final service = AttestationService(signer: signer, chainId: _chainId);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                TimestampScreen(service: service, wallet: auth.wallet!),
          ),
        );
      },
    );
  }
}

class _WalletCard extends StatelessWidget {
  final String address;
  const _WalletCard({required this.address});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connected Wallet',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(
                    address,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
