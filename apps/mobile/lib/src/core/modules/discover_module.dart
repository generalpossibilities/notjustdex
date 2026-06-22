import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:notjustdex_mini_app_runtime/notjustdex_mini_app_runtime.dart';
import 'app_module.dart';

class DiscoverModule extends AppModule {
  late MiniAppRegistry _registry;
  late NotJustDexJsBridge _bridge;

  DiscoverModule() {
    _registry = MiniAppRegistry();
    _bridge = NotJustDexJsBridge();
  }

  MiniAppRegistry get registry => _registry;
  NotJustDexJsBridge get bridge => _bridge;

  @override
  String get name => 'discover';

  @override
  String? get routePrefix => '/discover';

  @override
  bool get hasTab => true;

  @override
  List<GoRoute> get routes => [
    GoRoute(
      path: '/miniapps/store',
      builder: (_, state) => MiniAppStorePage(
        registry: _registry,
        bridge: _bridge,
      ),
    ),
    GoRoute(
      path: '/miniapps/open',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>;
        return MiniAppWebView(
          app: extra['app'] as MiniApp,
          bridge: _bridge,
        );
      },
    ),
  ];

  @override
  Widget? get tabWidget => _DiscoverTabContent(
    registry: _registry,
    bridge: _bridge,
    onOpenStore: () {},
  );

  @override
  NavigationDestination? get tabDestination => const NavigationDestination(
    icon: Icon(Icons.widgets_outlined),
    selectedIcon: Icon(Icons.widgets),
    label: 'Discover',
  );
}

class _DiscoverTabContent extends StatefulWidget {
  final MiniAppRegistry registry;
  final NotJustDexJsBridge bridge;
  final VoidCallback onOpenStore;

  const _DiscoverTabContent({
    required this.registry,
    required this.bridge,
    required this.onOpenStore,
  });

  @override
  State<_DiscoverTabContent> createState() => _DiscoverTabContentState();
}

class _DiscoverTabContentState extends State<_DiscoverTabContent> {
  @override
  void initState() {
    super.initState();
    if (widget.registry.installed.isEmpty) {
      final available = widget.registry.available;
      if (available.isNotEmpty) {
        widget.registry.install(available.first);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registry = widget.registry;
    final bridge = widget.bridge;

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: ListenableBuilder(
        listenable: registry,
        builder: (_, __) {
          final installed = registry.installed;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search NotJustDex...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (installed.isNotEmpty) ...[
                Text('My Apps',
                    style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: installed.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      if (i == installed.length) {
                        return _AppShortcut(
                          icon: Icons.add,
                          label: 'Store',
                          onTap: () => context.push('/miniapps/store'),
                        );
                      }
                      final app = installed[i];
                      return _AppShortcut(
                        icon: Icons.widgets_outlined,
                        label: app.name,
                        onTap: () => context.push('/miniapps/open', extra: {
                          'app': app,
                          'bridge': bridge,
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text('Mini App Store',
                  style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
              const SizedBox(height: 12),
              ...registry.available.take(4).map((app) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.widgets_outlined, color: theme.colorScheme.primary),
                      ),
                      title: Text(app.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(app.description,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: FilledButton.tonal(
                        onPressed: () => context.push('/miniapps/open', extra: {
                          'app': app, 'bridge': bridge,
                        }),
                        child: const Text('Open'),
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Mini App Store'),
                  onPressed: () => context.push('/miniapps/store'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AppShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
