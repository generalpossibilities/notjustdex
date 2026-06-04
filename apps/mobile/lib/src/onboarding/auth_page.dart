import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Unified auth page — Log In or Sign Up in a single screen.
/// Modes: phone (primary), passkey (returning), wallet (advanced).
class AuthPage extends StatefulWidget {
  /// 'login', 'register', or 'wallet'
  final String mode;
  const AuthPage({super.key, this.mode = 'register'});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        // Passkey registration (biometric)
        _AuthMethodCard(
          icon: Icons.fingerprint,
          title: 'Create with Passkey',
          subtitle: 'Use biometrics (Face ID / fingerprint) as your account key',
          onTap: () {
            // 1. Register passkey (WebAuthn)
            // 2. Create MPC wallet
            // 3. Navigate to phone verification
            context.push('/onboarding/phone');
          },
        ),

        const SizedBox(height: 16),

        // Phone registration
        _AuthMethodCard(
          icon: Icons.phone_android,
          title: 'Register with Phone',
          subtitle: 'Receive a verification code via SMS',
          onTap: () => context.push('/onboarding/phone'),
        ),

        const SizedBox(height: 16),

        // Wallet recovery
        _AuthMethodCard(
          icon: Icons.key,
          title: 'Recovery Phrase',
          subtitle: 'Restore using your 24-word seed phrase',
          onTap: () => _showRecoveryDialog(context),
          isSecondary: true,
        ),

        const SizedBox(height: 24),
        Text(
          'No crypto or blockchain terminology will appear during registration.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showRecoveryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Account'),
        content: const TextField(
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter your 24-word recovery phrase...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {}, child: const Text('Restore')),
        ],
      ),
    );
  }
}

// ─── Auth Method Card ───────────────────────────────────────────
class _AuthMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isSecondary;

  const _AuthMethodCard({
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
