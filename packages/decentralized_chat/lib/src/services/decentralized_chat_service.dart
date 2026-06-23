import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:notjustdex_mls_encryption/notjustdex_mls_encryption.dart';
import '../models/chat_message.dart';
import '../models/chat_conversation.dart';
import '../relay/relay_client.dart';
import 'conversation_store.dart';

/// High-level decentralized chat service.
///
///  1. Creates MLS groups for conversations
///  2. Encrypts messages with MLS before publishing to relays
///  3. Decrypts incoming messages from relays
///  4. Persists conversations + messages locally (Hive)
///  5. Connects to N relays for redundancy
class DecentralizedChatService {
  final ChatRelayClient _relay;
  final ConversationStore _store;
  MlsKeyStore? _keyStore;
  final Map<String, MlsGroup> _mlsGroups = {};
  String? _myAddress;
  final Set<String> _subscribedTopics = {};
  StreamSubscription<RelayEnvelope>? _relaySub;

  DecentralizedChatService({
    required ChatRelayClient relay,
    required ConversationStore store,
  })  : _relay = relay,
        _store = store;

  Stream<ChatMessage> get onMessage => _onMessageController.stream;
  final StreamController<ChatMessage> _onMessageController =
      StreamController<ChatMessage>.broadcast();

  /// Initialize with the user's identity address and MLS key store.
  Future<void> init({
    required String myAddress,
    required MlsKeyStore keyStore,
    List<String> relayUrls = const [],
  }) async {
    _myAddress = myAddress;
    _keyStore = keyStore;
    await _store.init();

    if (relayUrls.isNotEmpty) {
      await _relay.connect(relayUrls);
    }

    // Subscribe to existing conversation topics
    final conversations = _store.getConversations();
    for (final conv in conversations) {
      _subscribeToTopic(conv.id);
    }

    _relaySub = _relay.messages.listen(_handleRelayMessage);
  }

  /// Create a new conversation (1:1 or group).
  Future<ChatConversation> createConversation({
    required List<String> participantAddresses,
    required List<MlsKeyPackage> participantKeyPackages,
    String type = 'direct',
  }) async {
    if (_keyStore == null || _myAddress == null) {
      throw Exception('Chat service not initialized');
    }

    final convId = 'conv_${const Uuid().v4().replaceAll('-', '')}';
    final allParticipants = [if (!participantAddresses.contains(_myAddress)) _myAddress!, ...participantAddresses];

    // Create MLS group
    var group = MlsGroup.create(convId, _keyStore!);
    for (var i = 0; i < participantKeyPackages.length; i++) {
      final addr = allParticipants[i + 1];
      group = group.addMember(
        participantKeyPackages[i],
        _myAddress!,
        _keyStore!.signatureKeyPair,
      );
    }
    _mlsGroups[convId] = group;

    final conv = ChatConversation(
      id: convId,
      type: type,
      participantAddresses: allParticipants,
      createdAt: DateTime.now(),
      epoch: group.epoch,
    );

    await _store.saveConversation(conv);
    _subscribeToTopic(convId);

    return conv;
  }

  /// Send an MLS-encrypted message to a conversation.
  Future<ChatMessage> sendMessage(
    String conversationId,
    String content, {
    String contentType = 'text',
    String? replyToId,
  }) async {
    if (_keyStore == null || _myAddress == null) {
      throw Exception('Chat service not initialized');
    }

    final group = _mlsGroups[conversationId];
    if (group == null) {
      // Try to restore group from store
      throw Exception('MLS group not loaded for $conversationId');
    }

    final mlsMsg = await group.encryptMessage(
      _myAddress!,
      content,
      _keyStore!.signatureKeyPair,
    );

    final message = ChatMessage(
      id: 'msg_${const Uuid().v4().replaceAll('-', '')}',
      conversationId: conversationId,
      senderAddress: _myAddress!,
      content: content,
      contentType: contentType,
      epoch: mlsMsg.epoch,
      sentAt: DateTime.now(),
      isMe: true,
      replyToId: replyToId,
    );

    // Publish encrypted envelope to relays
    _relay.publish(conversationId, mlsMsg.toJson());

    // Save locally
    await _store.saveMessage(message);
    await _store.saveConversation(
      _store.getConversation(conversationId)!.copyWith(
        lastMessage: message,
        lastActiveAt: message.sentAt,
      ),
    );

    return message;
  }

  /// Get all conversations (from local store).
  List<ChatConversation> getConversations() {
    return _store.getConversations();
  }

  /// Get messages for a conversation (from local store).
  List<ChatMessage> getMessages(String conversationId, {int limit = 50, int offset = 0}) {
    return _store.getMessages(conversationId, limit: limit, offset: offset);
  }

  /// Load MLS group state for a conversation (needed to send messages).
  Future<void> loadGroupState(String conversationId, MlsGroup group) async {
    _mlsGroups[conversationId] = group;
    _subscribeToTopic(conversationId);
  }

  void _subscribeToTopic(String conversationId) {
    if (_subscribedTopics.add(conversationId)) {
      _relay.subscribe(conversationId);
    }
  }

  void _handleRelayMessage(RelayEnvelope envelope) {
    if (_myAddress == null) return;

    // Don't process our own messages
    if (envelope.senderAddress == _myAddress) return;

    final group = _mlsGroups[envelope.topic];
    if (group == null || _keyStore == null) return;

    try {
      final mlsMsg = MlsMessage.fromJson(envelope.payload);
      final plaintext = group.decryptMessage(mlsMsg, _keyStore!.encryptionKeyPair);

      final msg = ChatMessage(
        id: 'msg_${const Uuid().v4().replaceAll('-', '')}',
        conversationId: envelope.topic,
        senderAddress: envelope.senderAddress,
        content: plaintext,
        sentAt: DateTime.now(),
        epoch: mlsMsg.epoch,
      );

      _store.saveMessage(msg);
      _store.saveConversation(
        _store.getConversation(envelope.topic)?.copyWith(
          lastMessage: msg,
          lastActiveAt: msg.sentAt,
          unreadCount: (_store.getConversation(envelope.topic)?.unreadCount ?? 0) + 1,
        ) ?? ChatConversation(
          id: envelope.topic,
          type: 'direct',
          participantAddresses: [envelope.senderAddress, _myAddress!],
          lastMessage: msg,
          unreadCount: 1,
          createdAt: msg.sentAt,
          lastActiveAt: msg.sentAt,
        ),
      );

      _onMessageController.add(msg);
    } catch (_) {
      // Decryption failed — invalid message or not a member
    }
  }

  Future<void> dispose() async {
    await _relaySub?.cancel();
    _relay.disconnect();
    await _onMessageController.close();
  }
}
