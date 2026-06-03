import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/features.dart';

enum ModuleType { required, optional, enhanced }

abstract class AppModule {
  String get name;
  ModuleType get type => ModuleType.optional;
  bool get isAvailable => _available;
  bool _available = true;

  void setAvailable(bool v) => _available = v;

  /// Route prefix e.g. '/chat'
  String? get routePrefix => null;

  /// Routes this module contributes to the app router.
  List<GoRoute> get routes => [];

  /// Whether this module contributes a bottom nav tab.
  bool get hasTab => false;

  /// The bottom nav tab widget (only if hasTab).
  Widget? get tabWidget => null;

  /// NavigationBar destination for this tab.
  NavigationDestination? get tabDestination => null;

  /// Called when connection to the backend is established.
  Future<void> onConnect() async {}

  /// Called when connection is lost.
  void onDisconnect() {}

  /// Configure from feature flags.
  void configure(FeatureFlags flags) {
    _available = true;
  }
}

/// Builds the app's route tree from all registered modules.
class ModuleRouter {
  final List<AppModule> modules;

  ModuleRouter(this.modules);

  List<GoRoute> build(List<GoRoute> baseRoutes) {
    final all = <GoRoute>[...baseRoutes];
    for (final m in modules) {
      if (m.isAvailable) {
        all.addAll(m.routes);
      }
    }
    return all;
  }

  NavigationDestination Function(int, bool) tabBuilder() {
    return (index, selected) {
      final available = modules.where((m) => m.hasTab && m.isAvailable).toList();
      if (index >= available.length) {
        return const NavigationDestination(icon: SizedBox(), label: '');
      }
      return available[index].tabDestination ??
          const NavigationDestination(icon: SizedBox(), label: '');
    };
  }

  int tabCount() {
    return modules.where((m) => m.hasTab && m.isAvailable).length;
  }
}
