import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_module.dart';
import '../../notifications/notification_client.dart';
import '../../notifications/notification_page.dart';

const _notifHost = '10.0.2.2:8087';

class NotificationsModule extends AppModule {
  final client = NotificationClient(baseUrl: _notifHost);
  int badgeCount = 0;

  @override
  String get name => 'notifications';

  @override
  String? get routePrefix => '/notifications';

  @override
  bool get hasTab => true;

  @override
  Widget? get tabWidget => NotificationsPage(client: client, userId: 'current_user');

  @override
  NavigationDestination? get tabDestination => NavigationDestination(
    icon: badgeCount > 0
        ? Badge(
            label: Text('$badgeCount'),
            child: const Icon(Icons.notifications_outlined),
          )
        : const Icon(Icons.notifications_outlined),
    selectedIcon: badgeCount > 0
        ? Badge(
            label: Text('$badgeCount'),
            child: const Icon(Icons.notifications),
          )
        : const Icon(Icons.notifications),
    label: 'Activity',
  );

  @override
  Future<void> onConnect() async {
    await client.connect('current_user');
    badgeCount = await client.getUnreadCount('current_user');
  }

  @override
  void onDisconnect() {
    client.disconnect();
    badgeCount = 0;
  }
}
