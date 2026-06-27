import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:notjustdex_identity_kernel/identity_kernel.dart';
import 'app_module.dart';
import '../../feed/unified_feed_page.dart';
import '../../feed/services/feed_api.dart';

class FeedModule extends AppModule {
  final FeedApiClient api;

  FeedModule({FeedApiClient? api, DecentralizedFeedService? decentralizedFeed, IpfsClient? ipfs})
      : api = api ?? FeedApiClient(
          decentralizedFeed: decentralizedFeed,
          ipfs: ipfs,
        );

  @override
  String get name => 'feed';

  @override
  String? get routePrefix => '/feed';

  @override
  bool get hasTab => true;

  @override
  List<GoRoute> get routes => [
    GoRoute(
      path: '/feed',
      builder: (_, __) => UnifiedFeedPage(api: api),
    ),
  ];

  @override
  Widget? get tabWidget => UnifiedFeedPage(api: api);

  @override
  NavigationDestination? get tabDestination => const NavigationDestination(
    icon: Icon(Icons.explore_outlined),
    selectedIcon: Icon(Icons.explore),
    label: 'Feed',
  );
}
