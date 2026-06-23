import 'dart:async';
import 'package:notjustdex_decentralized_chat/notjustdex_decentralized_chat.dart';
import 'package:notjustdex_mls_encryption/notjustdex_mls_encryption.dart';

/// Decentralized chat client wrapping DecentralizedChatService.
///
/// Preserves the same Stream<ChatMessage> interface as the old Go-based
/// ChatClient so existing consumer code doesn't break.
class ChatClient {
  final DecentralizedChatService _service;
  final ChatRelayClient _relayClient;
  final ConversationStore _store;

  ChatClient({
    required DecentralizedChatService service,
    required ChatRelayClient relayClient,
    required ConversationStore store,
  })  : _service = service,
        _relayClient = relayClient,
        _store = store;

  Stream<ChatMessage> get messages => _service.onMessage;

  /// Connect using identity address and MLS key store.
  Future<void> connect({
    required String userId,
    required MlsKeyStore keyStore,
    List<String> relayUrls = const [],
  }) async {
    await _service.init(
      myAddress: userId,
      keyStore: keyStore,
      relayUrls: relayUrls,
    );
  }

  Future<void> sendMessage(String conversationId, String content,
      {String contentType = 'text'}) async {
    await _service.sendMessage(conversationId, content, contentType: contentType);
  }

  void sendTyping(String conversationId) {
    // Typing indicators via relay — could be added as a relay message type
  }

  List<ChatConversation> getConversations() {
    return _service.getConversations();
  }

  List<ChatMessage> getMessages(String conversationId, {int limit = 50, int offset = 0}) {
    return _service.getMessages(conversationId, limit: limit, offset: offset);
  }

  void disconnect() {
    _relayClient.disconnect();
  }
}
