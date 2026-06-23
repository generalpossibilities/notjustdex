import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthPage extends StatefulWidget {
  final String mode;
  const AuthPage({super.key, this.mode = 'register'});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = switch (widget.mode) {
      'login' => 1,
      'wallet' => 2,
      _ => 0,
    };
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('NotJustDex'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Register'),
            Tab(text: 'Log In'),
            Tab(text: 'Wallet'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RegisterTab(),
          _LoginTab(),
          _WalletTab(),
        ],
      ),
    );
  }
}

class _RegisterTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Text('Create your account',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('No blockchain or crypto terminology — just a social account.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        _AuthCard(
          icon: Icons.fingerprint,
          title: 'Create with Passkey',
          subtitle: 'Use Face ID or fingerprint as your account key',
          onTap: () => _startRegister(context),
        ),
        const SizedBox(height: 16),
        _AuthCard(
          icon: Icons.phone_android,
          title: 'Register with Phone',
          subtitle: 'Receive verification code via SMS',
          onTap: () => context.push('/onboarding/phone'),
          isSecondary: true,
        ),
      ],
    );
  }

  void _startRegister(BuildContext context) {
    context.push('/onboarding/phone');
  }
}

class _LoginTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Text('Welcome back',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Sign in using your preferred method.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        _AuthCard(
          icon: Icons.fingerprint,
          title: 'Passkey (Recommended)',
          subtitle: 'Fast biometric login with Face ID / fingerprint',
          onTap: () {
            // 1. WebAuthn assertion
            // 2. Recover wallet from passkey credential ID
            // 3. Navigate to /home
          },
        ),
        const SizedBox(height: 16),
        _AuthCard(
          icon: Icons.phone_android,
          title: 'Phone Verification',
          subtitle: 'Sign in with SMS verification code',
          onTap: () => context.push('/onboarding/phone'),
          isSecondary: true,
        ),
        const SizedBox(height: 16),
        _AuthCard(
          icon: Icons.key,
          title: 'Recovery Phrase',
          subtitle: 'Restore using your 24-word seed phrase',
          onTap: () => _showRecoveryDialog(context),
          isSecondary: true,
        ),
      ],
    );
  }

  void _showRecoveryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Account'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter your 24-word recovery phrase...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Validate and restore wallet from seed phrase
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}

class _WalletTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Text('Wallet Sign-In',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Advanced: prove ownership of your wallet using a zero-knowledge proof.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        _AuthCard(
          icon: Icons.verified_user,
          title: 'Sign with Wallet',
          subtitle: 'Zero-knowledge proof challenge signed by your wallet',
          onTap: () {
            // 1. Generate challenge
            // 2. Request wallet to sign
            // 3. Verify signature on chain
          },
        ),
        const SizedBox(height: 24),
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This method requires your wallet to be connected to this device. '
                    'Use Passkey for the simplest experience.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isSecondary;

  const _AuthCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: isSecondary ? 0 : 1,
      color: isSecondary
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSecondary
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primaryContainer,
          child: Icon(icon, color: isSecondary ? null : theme.colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
