import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/services/session_service.dart';

/// Shown after phone verification if identity is incomplete.
/// User can create a username, connect an existing wallet, or skip for now.
class WalletAskPage extends StatelessWidget {
  final String phoneNumber;

  const WalletAskPage({super.key, required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = SessionService();

    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Your Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Icon(Icons.verified_user, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Phone verified!', style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 8),
            Text(
              'Now set up your on-chain identity to unlock all features. '
              'You can also do this later from your profile.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            _OptionCard(
              icon: Icons.person_add,
              title: 'Create a Username',
              subtitle: 'Choose a unique name — it becomes your wallet on the chain',
              onTap: () => context.push('/onboarding/username', extra: phoneNumber),
            ),
            const SizedBox(height: 12),
            _OptionCard(
              icon: Icons.qr_code_scanner,
              title: 'Connect Existing Wallet',
              subtitle: 'Link your Acki Nacki wallet via QR code or credentials',
              onTap: () => context.push('/onboarding/wallet-connect', extra: phoneNumber),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  session.saveSession(
                    token: phoneNumber.hashCode.toString(),
                    userId: '',
                    username: '',
                    phoneNumber: phoneNumber,
                  );
                  context.go('/home');
                },
                child: Text(
                  'Skip for now — I\'ll do it later',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
