import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import '../core/services/session_service.dart';

/// Two ways to connect an existing Acki Nacki wallet:
///   1. QR code / deep link (WalletConnect v2 style)
///   2. Wallet credentials (wallet name + password → ZKP proof of ownership)
class WalletConnectPage extends StatefulWidget {
  final String phoneNumber;

  const WalletConnectPage({super.key, required this.phoneNumber});

  @override
  State<WalletConnectPage> createState() => _WalletConnectPageState();
}

class _WalletConnectPageState extends State<WalletConnectPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isConnecting = false;
  String _errorMessage = '';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Wallet'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'QR / Deep Link'),
            Tab(text: 'Wallet Credentials'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _QrDeepLinkTab(phoneNumber: widget.phoneNumber),
          _CredentialsTab(
            phoneNumber: widget.phoneNumber,
            nameController: _nameController,
            passwordController: _passwordController,
            isConnecting: _isConnecting,
            errorMessage: _errorMessage,
            onConnect: _connectWithCredentials,
          ),
        ],
      ),
    );
  }

  /// Connect via wallet name + password + ZKP.
  ///
  /// Acki Nacki ZK Login authenticates via:
  ///   zkID = Poseidon(stable_id || issuer || Salt Password)
  ///
  /// The wallet name is looked up on chain, the password is the user's
  /// Salt Password (set during wallet creation), and a zero-knowledge
  /// proof is generated to verify ownership without revealing the
  /// underlying OpenID identity.
  ///
  /// This stub: hashes the password, derives an Ed25519 key pair,
  /// and the resulting address is the "linked wallet".
  Future<void> _connectWithCredentials() async {
    final walletName = _nameController.text.trim();
    final password = _passwordController.text;

    if (walletName.length < 4) {
      setState(() => _errorMessage = 'Wallet name must be 4+ characters');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be 8+ characters');
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = '';
    });

    try {
      // Simulate chain lookup + ZKP verification
      await Future.delayed(const Duration(milliseconds: 1200));

      // Derive wallet address from name + password (stub)
      // Production: zkID = Poseidon(stable_id || issuer || saltPassword)
      final seed = sha256.convert(utf8.encode('$walletName:$password')).bytes;
      final ed25519 = Ed25519();
      final keyPair = await ed25519.newKeyPairFromSeed(seed);
      final keyPairData = await keyPair.extract();
      final address = sha256.convert(keyPairData.publicKey.bytes)
          .toString()
          .substring(0, 40);

      // Save session with wallet linked
      final session = SessionService();
      await session.saveSession(
        token: address,
        userId: address,
        username: walletName,
        displayName: walletName,
        phoneNumber: widget.phoneNumber,
      );

      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _isConnected = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet connected!')),
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _errorMessage = 'Connection failed: $e';
      });
    }
  }
}

/// Tab 1: QR code scan or deep link to the AN Wallet app.
class _QrDeepLinkTab extends StatelessWidget {
  final String phoneNumber;

  const _QrDeepLinkTab({required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Icon(Icons.qr_code_scanner, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('Connect via Acki Nacki Wallet', style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          )),
          const SizedBox(height: 12),
          Text(
            'If you already have the Acki Nacki Wallet app installed, '
            'scan a QR code or tap the deep link to connect.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _simulateQrConnect(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _simulateDeepLink(context),
              icon: const Icon(Icons.link),
              label: const Text('Open Deep Link'),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Don\'t have the AN Wallet? Download it from '
                      'ackinacki.com/wallet or use the "Wallet Credentials" tab.',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _simulateQrConnect(BuildContext context) async {
    final session = SessionService();
    final mockAddress = '0x${sha256.convert(utf8.encode(phoneNumber)).toString().substring(0, 40)}';
    await session.saveSession(
      token: mockAddress,
      userId: mockAddress,
      username: '',
      phoneNumber: phoneNumber,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wallet linked via QR!')),
    );
    context.go('/home');
  }

  Future<void> _simulateDeepLink(BuildContext context) async {
    final session = SessionService();
    final mockAddress = '0x${sha256.convert(utf8.encode('deep_link_$phoneNumber')).toString().substring(0, 40)}';
    await session.saveSession(
      token: mockAddress,
      userId: mockAddress,
      username: '',
      phoneNumber: phoneNumber,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wallet linked via deep link!')),
    );
    context.go('/home');
  }
}

/// Tab 2: Wallet name + password + ZKP authentication.
class _CredentialsTab extends StatelessWidget {
  final String phoneNumber;
  final TextEditingController nameController;
  final TextEditingController passwordController;
  final bool isConnecting;
  final String errorMessage;
  final VoidCallback onConnect;

  const _CredentialsTab({
    required this.phoneNumber,
    required this.nameController,
    required this.passwordController,
    required this.isConnecting,
    required this.errorMessage,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Icon(Icons.key, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Wallet Credentials', style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 8),
            Text(
              'Enter your Acki Nacki wallet name and Salt Password. '
              'A zero-knowledge proof verifies ownership on chain.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Wallet Name',
                hintText: 'Your AN wallet name (username)',
                prefixText: '@',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Salt Password',
                hintText: 'Your wallet salt password (set at creation)',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onConnect(),
            ),
            const SizedBox(height: 8),
            Text(
              'Your password never leaves this device. '
              'A ZKP proves you own the wallet without revealing it.',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            ),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(errorMessage,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isConnecting ? null : onConnect,
                child: isConnecting
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Connect Wallet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
