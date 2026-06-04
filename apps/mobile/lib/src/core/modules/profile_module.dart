import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_module.dart';
import '../../settings/profile_settings_page.dart';


class ProfileModule extends AppModule {
  @override
  String get name => 'profile';

  @override
  ModuleType get type => ModuleType.required;

  @override
  String? get routePrefix => '/settings';

  @override
  bool get hasTab => true;

  @override
  List<GoRoute> get routes => [
    GoRoute(
      path: '/settings/profile',
      builder: (_, __) => const ProfileSettingsPage(),
    ),
  ];

  @override
  Widget? get tabWidget => const _ProfileTabContent();

  @override
  NavigationDestination? get tabDestination => const NavigationDestination(
    icon: Icon(Icons.person_outlined),
    selectedIcon: Icon(Icons.person),
    label: 'Profile',
  );
}

class _ProfileTabContent extends StatefulWidget {
  const _ProfileTabContent();

  @override
  State<_ProfileTabContent> createState() => _ProfileTabContentState();
}

class _ProfileTabContentState extends State<_ProfileTabContent> {
  // In production: read from AuthClient cache / Identity Bloc
  String _username = '@username';
  String _displayName = 'Display Name';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadProfile() async {
    // In production: fetch from UsersClient
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  if (_avatarUrl != null)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(_username, textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(_displayName, textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Settings'),
              onPressed: () => context.push('/settings/profile'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Refresh Profile'),
              onPressed: _loadProfile,
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.fingerprint, color: Colors.green, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Passkey', style: theme.textTheme.titleSmall),
                          Text('Secured with biometrics',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
