import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(Icons.forum, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'NotJustDex',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect. Create. Own.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 1),
              FilledButton(
                onPressed: () => context.push('/onboarding/phone'),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/tour'),
                child: const Text('Browse First'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.push('/auth', extra: 'login'),
                child: Text(
                  'I already have an account',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
