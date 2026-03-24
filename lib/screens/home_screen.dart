import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';

import '../privy/privy_module.dart';
import '../protocol/protocol_module.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../providers/app_wallet_provider.dart';

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
  String? _rpcUrl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.create();
    if (mounted) {
      setState(() {
        _chainId = settings.selectedChainId;
        _rpcUrl = settings.rpcUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<AppWalletProvider>();
    final auth = walletProvider.privyAuth;

    if (auth == null || !auth.isReady) {
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
              // Reload settings in case the user changed them.
              if (mounted) _loadSettings();
            },
          ),
          if (walletProvider.connectionType != ConnectionType.none)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Disconnect',
              onPressed: () => walletProvider.disconnect(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (walletProvider.connectionType != ConnectionType.none) ...[
              _WalletCard(
                address: walletProvider.walletAddress ?? 'Unknown',
                type: walletProvider.connectionType,
              ),
              const SizedBox(height: 16),
            ],

            if (walletProvider.connectionType == ConnectionType.none) ...[
              _buildLoginButton(context),
              const SizedBox(height: 12),
            ],

            // --- Always available ---
            _SectionHeader('Offchain Operations'),
            _buildSignOffchainButton(context, walletProvider),
            const SizedBox(height: 8),
            _buildVerifyButton(context),
            const SizedBox(height: 24),

            // --- Onchain ---
            if (walletProvider.canSendTransactions) ...[
              _SectionHeader('Onchain Operations'),
              _buildOnchainAttestButton(context, walletProvider),
              const SizedBox(height: 8),
              _buildRegisterSchemaButton(context, walletProvider),
              const SizedBox(height: 8),
              _buildTimestampButton(context, walletProvider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => showPrivyLoginModal(context),
      icon: const Icon(Icons.account_balance_wallet),
      label: const Text('Connect Wallet'),
    );
  }

  Widget _buildSignOffchainButton(BuildContext context, AppWalletProvider walletProvider) {
    return _ActionButton(
      icon: Icons.edit_note,
      label: 'Sign Offchain Attestation',
      onPressed: () async {
        if (walletProvider.connectionType == ConnectionType.none) {
          showPrivyLoginModal(context);
          return;
        }

        final signer = walletProvider.getSigner(context, _chainId);
        if (signer == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not initialize signer')),
          );
          return;
        }

        final isSponsored = dotenv.env['GAS_SPONSORSHIP']?.toLowerCase() == 'true';
        final service = AttestationService(
          signer: signer,
          chainId: _chainId,
          rpcUrl: _rpcUrl ?? '',
          sponsorGas: isSponsored,
        );
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SignScreen(service: service)),
        );
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
        final isSponsored = dotenv.env['GAS_SPONSORSHIP']?.toLowerCase() == 'true';
        final service = AttestationService(
          signer: dummySigner,
          chainId: _chainId,
          rpcUrl: _rpcUrl ?? '',
          sponsorGas: isSponsored,
        );
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VerifyScreen(service: service)),
        );
      },
    );
  }

  Widget _buildOnchainAttestButton(BuildContext context, AppWalletProvider walletProvider) {
    return _ActionButton(
      icon: Icons.cloud_upload,
      label: 'Attest Onchain',
      onPressed: () {
        final signer = walletProvider.getSigner(context, _chainId);
        if (signer == null) return;
        final isSponsored = dotenv.env['GAS_SPONSORSHIP']?.toLowerCase() == 'true';
        final service = AttestationService(
          signer: signer,
          chainId: _chainId,
          rpcUrl: _rpcUrl ?? '',
          sponsorGas: isSponsored,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OnchainAttestScreen(service: service),
          ),
        );
      },
    );
  }

  Widget _buildRegisterSchemaButton(BuildContext context, AppWalletProvider walletProvider) {
    return _ActionButton(
      icon: Icons.app_registration,
      label: 'Register Schema',
      onPressed: () {
        final signer = walletProvider.getSigner(context, _chainId);
        if (signer == null) return;
        final isSponsored = dotenv.env['GAS_SPONSORSHIP']?.toLowerCase() == 'true';
        final service = AttestationService(
          signer: signer,
          chainId: _chainId,
          rpcUrl: _rpcUrl ?? '',
          sponsorGas: isSponsored,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RegisterSchemaScreen(service: service),
          ),
        );
      },
    );
  }

  Widget _buildTimestampButton(BuildContext context, AppWalletProvider walletProvider) {
    return _ActionButton(
      icon: Icons.access_time,
      label: 'Timestamp Offchain UID',
      onPressed: () {
        final signer = walletProvider.getSigner(context, _chainId);
        if (signer == null) return;
        final isSponsored = dotenv.env['GAS_SPONSORSHIP']?.toLowerCase() == 'true';
        final service = AttestationService(
          signer: signer,
          chainId: _chainId,
          rpcUrl: _rpcUrl ?? '',
          sponsorGas: isSponsored,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TimestampScreen(service: service),
          ),
        );
      },
    );
  }
}

class _WalletCard extends StatelessWidget {
  final String address;
  final ConnectionType type;
  const _WalletCard({required this.address, required this.type});

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (type) {
      ConnectionType.privy => 'Privy Wallet',
      ConnectionType.external => 'External Wallet',
      ConnectionType.privateKey => 'Private Key',
      ConnectionType.none => 'None',
    };

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
                  Text(
                    typeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
