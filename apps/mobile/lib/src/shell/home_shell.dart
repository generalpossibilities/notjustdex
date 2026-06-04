import 'package:flutter/material.dart';
import '../core/modules/app_module.dart';

class HomeShell extends StatefulWidget {
  final List<AppModule> modules;

  const HomeShell({super.key, required this.modules});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  List<AppModule> get _tabs =>
      widget.modules.where((m) => m.hasTab && m.isAvailable).toList();

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;

    if (tabs.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('No modules available',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  // reconnect
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex.clamp(0, tabs.length - 1),
        children: [
          for (final tab in tabs)
            if (tab.tabWidget != null) tab.tabWidget!,
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex.clamp(0, tabs.length - 1),
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          for (final tab in tabs)
            if (tab.tabDestination != null) tab.tabDestination!,
        ],
      ),
    );
  }
}
