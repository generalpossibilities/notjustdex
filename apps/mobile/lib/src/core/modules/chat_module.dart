import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:notjustdex_decentralized_chat/notjustdex_decentralized_chat.dart';
import 'package:notjustdex_mls_encryption/notjustdex_mls_encryption.dart';
import 'app_module.dart';
import '../config/features.dart';
import '../../chat/chat_client.dart';
import '../../chat/conversation_list_page.dart';
import '../../chat/chat_view_page.dart';

class ChatModule extends AppModule {
  final AppConfig config;
  ChatClient? _chatClient;

  ChatModule({required this.config});

  @override
  String get name => 'chat';

  @override
  String? get routePrefix => '/chat';

  @override
  bool get hasTab => true;

  ChatClient? get chatClient => _chatClient;

  /// Initialize the decentralized chat service.
  Future<void> initialize({
    required String myAddress,
    required MlsKeyStore keyStore,
    List<String> relayUrls = const [],
  }) async {
    final store = ConversationStore();
    await store.init();
    final relayClient = ChatRelayClient();
    final service = DecentralizedChatService(
      relay: relayClient,
      store: store,
    );
    _chatClient = ChatClient(
      service: service,
      relayClient: relayClient,
      store: store,
    );
    await _chatClient!.connect(
      userId: myAddress,
      keyStore: keyStore,
      relayUrls: relayUrls,
    );
  }

  @override
  List<GoRoute> get routes => [
    GoRoute(
      path: '/chat',
      builder: (_, __) => ConversationListPage(chatClient: _chatClient),
    ),
    GoRoute(
      path: '/chat/view',
      builder: (_, state) => ChatViewPage(
        conversation: state.extra as ChatConversation,
        chatClient: _chatClient,
      ),
    ),
  ];

  @override
  Widget? get tabWidget => ConversationListPage(chatClient: _chatClient);

  @override
  NavigationDestination? get tabDestination => const NavigationDestination(
    icon: Icon(Icons.chat_outlined),
    selectedIcon: Icon(Icons.chat),
    label: 'Chat',
  );
}
