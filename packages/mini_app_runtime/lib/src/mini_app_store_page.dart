import 'package:flutter/material.dart';
import 'models/mini_app.dart';
import 'store/mini_app_registry.dart';
import 'mini_app_webview.dart';
import 'bridge/js_bridge.dart';

class MiniAppStorePage extends StatelessWidget {
  final MiniAppRegistry registry;
  final NotJustDexJsBridge bridge;

  const MiniAppStorePage({
    super.key,
    required this.registry,
    required this.bridge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mini Apps')),
      body: ListenableBuilder(
        listenable: registry,
        builder: (_, __) {
          final installed = registry.installed;
          final available = registry.available;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (installed.isNotEmpty) ...[
                Text('Installed',
                    style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
                const SizedBox(height: 8),
                ...installed.map((app) => _MiniAppTile(
                      app: app,
                      isInstalled: true,
                      onTap: () => _openMiniApp(context, app),
                      onUninstall: () => registry.uninstall(app.id),
                    )),
                const SizedBox(height: 24),
              ],
              Text('Discover',
                  style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
              const SizedBox(height: 8),
              ...available.map((app) => _MiniAppTile(
                    app: app,
                    isInstalled: false,
                    onTap: () => _installAndOpen(context, app),
                    onUninstall: null,
                  )),
            ],
          );
        },
      ),
    );
  }

  void _installAndOpen(BuildContext context, MiniApp app) async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (_) => PermissionRequestDialog(app: app),
    );
    if (allowed == true && context.mounted) {
      registry.install(app);
      _openMiniApp(context, app);
    }
  }

  void _openMiniApp(BuildContext context, MiniApp app) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MiniAppWebView(app: app, bridge: bridge),
      ),
    );
  }
}

class _MiniAppTile extends StatelessWidget {
  final MiniApp app;
  final bool isInstalled;
  final VoidCallback onTap;
  final VoidCallback? onUninstall;

  const _MiniAppTile({
    required this.app,
    required this.isInstalled,
    required this.onTap,
    this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.widgets_outlined, color: theme.colorScheme.primary),
        ),
        title: Text(app.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(app.description,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: isInstalled
            ? PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'uninstall') onUninstall?.call();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'uninstall', child: Text('Uninstall')),
                ],
              )
            : FilledButton.tonal(
                onPressed: onTap,
                child: const Text('Install'),
              ),
        onTap: isInstalled ? onTap : null,
      ),
    );
  }
}
