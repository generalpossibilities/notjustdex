import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_module.dart';
import '../../chat/conversation_list_page.dart';
import '../../chat/chat_view_page.dart';

class ChatModule extends AppModule {
  @override
  String get name => 'chat';

  @override
  String? get routePrefix => '/chat';

  @override
  bool get hasTab => true;

  @override
  List<GoRoute> get routes => [
    GoRoute(path: '/chat', builder: (_, __) => const ConversationListPage()),
    GoRoute(
      path: '/chat/view',
      builder: (_, state) => ChatViewPage(
        conversation: state.extra as Map<String, dynamic>,
      ),
    ),
  ];

  @override
  Widget? get tabWidget => const ConversationListPage();

  @override
  NavigationDestination? get tabDestination => const NavigationDestination(
    icon: Icon(Icons.chat_outlined),
    selectedIcon: Icon(Icons.chat),
    label: 'Chat',
  );
}
