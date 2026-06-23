import 'dart:async';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:notjustdex_mls_encryption/mls_encryption.dart';
import 'package:notjustdex_identity_kernel/identity_kernel.dart';
import '../models/chat_message.dart';
import '../models/chat_conversation.dart';
import '../relay/relay_client.dart';
import 'conversation_store.dart';
import 'mls_group_store.dart';

/// High-level decentralized chat service.
///
///  1. Creates MLS groups for conversations
///  2. Encrypts messages with MLS before publishing to relays
///  3. Decrypts incoming messages from relays
///  4. Persists conversations + messages locally (Hive)
///  5. Persists MLS group state to Hive (encrypted at rest)
///  6. Backs up encrypted messages to IPFS for cross-device recovery
///  7. Connects to N relays for redundancy
class DecentralizedChatService {
  final ChatRelayClient _relay;
  final ConversationStore _store;
  final MlsGroupStore _groupStore;
  MlsKeyStore? _keyStore;
  final Map<String, MlsGroup> _mlsGroups = {};
  String? _myAddress;
  final Set<String> _subscribedTopics = {};
  StreamSubscription<RelayEnvelope>? _relaySub;
  // ignore: unused_field
  IpfsClient? _ipfs;
  // ignore: unused_field
  String? _chainEndpoint;

  DecentralizedChatService({
    required ChatRelayClient relay,
    required ConversationStore store,
    MlsGroupStore? groupStore,
  })  : _relay = relay,
        _store = store,
        _groupStore = groupStore ?? MlsGroupStore();

  Stream<ChatMessage> get onMessage => _onMessageController.stream;
  final StreamController<ChatMessage> _onMessageController =
      StreamController<ChatMessage>.broadcast();

  /// Initialize with the user's identity address and MLS key store.
  ///
  /// If [walletSeed] is provided, the MLS key store is derived deterministically
  /// from it (enabling cross-device recovery). If [keyStore] is provided directly,
  /// that takes precedence.
  ///
  /// Options for backup:
  /// - [ipfs] — IPFS client for uploading encrypted message backups
  /// - [chainEndpoint] — chain endpoint for committing backup CIDs
  Future<void> init({
    required String myAddress,
    MlsKeyStore? keyStore,
    Uint8List? walletSeed,
    List<String> relayUrls = const [],
    IpfsClient? ipfs,
    String? chainEndpoint,
  }) async {
    _myAddress = myAddress;
    _ipfs = ipfs;
    _chainEndpoint = chainEndpoint;

    if (keyStore != null) {
      _keyStore = keyStore;
    } else if (walletSeed != null) {
      _keyStore = await MlsKeyStore.fromSeed(myAddress, walletSeed);
    } else {
      _keyStore = await MlsKeyStore.generate(myAddress);
    }

    await _store.init();
    await _groupStore.init(
      encryptionKey: Uint8List.fromList(_keyStore!.encryptionKeyPair.bytes),
    );

    // Restore MLS groups from Hive
    final savedGroups = await _groupStore.loadAllGroups();
    for (final entry in savedGroups) {
      _mlsGroups[entry.key] = entry.value;
      _subscribeToTopic(entry.key);
    }

    if (relayUrls.isNotEmpty) {
      await _relay.connect(relayUrls);
    }

    // Subscribe to any conversations that don't have groups restored yet
    final conversations = _store.getConversations();
    for (final conv in conversations) {
      if (!_mlsGroups.containsKey(conv.id)) {
        _subscribeToTopic(conv.id);
      }
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
      group = group.addMember(
        participantKeyPackages[i],
        _myAddress!,
        _keyStore!.signatureKeyPair,
      );
    }
    _mlsGroups[convId] = group;
    await _groupStore.saveGroup(convId, group);

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
    await _groupStore.saveGroup(conversationId, group);
    _subscribeToTopic(conversationId);
  }

  /// Get the user's MLS key store (for exporting key packages).
  MlsKeyStore? get keyStore => _keyStore;

  /// Get an MLS group by conversation ID.
  MlsGroup? getGroup(String conversationId) => _mlsGroups[conversationId];

  void _subscribeToTopic(String conversationId) {
    if (_subscribedTopics.add(conversationId)) {
      _relay.subscribe(conversationId);
    }
  }

  Future<void> _handleRelayMessage(RelayEnvelope envelope) async {
    if (_myAddress == null) return;

    // Don't process our own messages
    if (envelope.senderAddress == _myAddress) return;

    final group = _mlsGroups[envelope.topic];
    if (group == null || _keyStore == null) return;

    try {
      final mlsMsg = MlsMessage.fromJson(envelope.payload);
      final plaintext = await group.decryptMessage(mlsMsg, _keyStore!.encryptionKeyPair);

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
