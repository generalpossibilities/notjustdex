import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:notjustdex_identity_kernel/identity_kernel.dart';
import 'app_module.dart';
import '../../vault/vault_page.dart';
import '../../vault/vault_entry_form.dart';
import '../../vault/vault_detail_page.dart';
import '../../vault/vault_settings_page.dart';

class VaultModule extends AppModule {
  final VaultService? vaultService;

  VaultModule({this.vaultService});

  @override
  String get name => 'vault';

  @override
  String? get routePrefix => '/vault';

  @override
  bool get hasTab => true;

  @override
  List<GoRoute> get routes => [
    GoRoute(
      path: '/vault',
      builder: (_, __) => vaultService != null
          ? VaultPage(vaultService: vaultService!)
          : _VaultNotConnected(),
    ),
    GoRoute(
      path: '/vault/new',
      builder: (_, __) => vaultService != null
          ? VaultEntryFormPage(vaultService: vaultService!)
          : _VaultNotConnected(),
    ),
    GoRoute(
      path: '/vault/detail',
      builder: (_, state) => vaultService != null
          ? VaultDetailPage(
              entry: state.extra as VaultEntry,
              vaultService: vaultService!,
            )
          : _VaultNotConnected(),
    ),
    GoRoute(
      path: '/vault/settings',
      builder: (_, __) => vaultService != null
          ? VaultSettingsPage(vaultService: vaultService!)
          : _VaultNotConnected(),
    ),
  ];

  @override
  Widget? get tabWidget => vaultService != null
      ? VaultPage(vaultService: vaultService!)
      : _VaultNotConnected();

  @override
  NavigationDestination? get tabDestination => const NavigationDestination(
    icon: Icon(Icons.lock_outline),
    selectedIcon: Icon(Icons.lock),
    label: 'Vault',
  );
}

class _VaultNotConnected extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Vault not initialized',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Sign in to access your vault',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
