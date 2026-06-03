import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_module.dart';
import '../../feed/unified_feed_page.dart';

class FeedModule extends AppModule {
  @override
  String get name => 'feed';

  @override
  String? get routePrefix => '/feed';

  @override
  bool get hasTab => true;

  @override
  List<GoRoute> get routes => [
    GoRoute(path: '/feed', builder: (_, __) => const UnifiedFeedPage()),
  ];

  @override
  Widget? get tabWidget => const UnifiedFeedPage();

  @override
  NavigationDestination? get tabDestination => const NavigationDestination(
    icon: Icon(Icons.explore_outlined),
    selectedIcon: Icon(Icons.explore),
    label: 'Feed',
  );
}
