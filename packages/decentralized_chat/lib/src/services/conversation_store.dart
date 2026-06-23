import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

/// Hive-backed persistent store for conversations and messages.
class ConversationStore {
  static const _convBoxName = 'conversations';
  static const _msgBoxName = 'chat_messages';
  late Box<String> _convBox;
  late Box<String> _msgBox;

  Future<void> init() async {
    _convBox = await Hive.openBox<String>(_convBoxName);
    _msgBox = await Hive.openBox<String>(_msgBoxName);
  }

  // -- Conversations --

  List<ChatConversation> getConversations() {
    return _convBox.values.map((v) {
      return ChatConversation.fromJson(jsonDecode(v) as Map<String, dynamic>);
    }).toList()
      ..sort((a, b) {
        final aTime = a.lastActiveAt ?? a.createdAt;
        final bTime = b.lastActiveAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
  }

  ChatConversation? getConversation(String id) {
    final json = _convBox.get(id);
    if (json == null) return null;
    return ChatConversation.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveConversation(ChatConversation conv) async {
    await _convBox.put(conv.id, jsonEncode(conv.toJson()));
  }

  Future<void> deleteConversation(String id) async {
    await _convBox.delete(id);
  }

  // -- Messages --

  List<ChatMessage> getMessages(String conversationId, {int limit = 50, int offset = 0}) {
    final prefix = '$conversationId:';
    final keys = _msgBox.keys
        .whereType<String>()
        .where((k) => k.startsWith(prefix))
        .toList()
      ..sort();
    final slice = keys.reversed.toList().skip(offset).take(limit);
    return slice.map((k) {
      return ChatMessage.fromJson(
        jsonDecode(_msgBox.get(k)!) as Map<String, dynamic>,
      );
    }).toList();
  }

  Future<void> saveMessage(ChatMessage msg) async {
    final key = '${msg.conversationId}:${msg.id}';
    await _msgBox.put(key, jsonEncode(msg.toJson()));
  }

  Future<void> deleteMessages(String conversationId) async {
    final prefix = '$conversationId:';
    final keys = _msgBox.keys
        .whereType<String>()
        .where((k) => k.startsWith(prefix))
        .toList();
    for (final k in keys) {
      await _msgBox.delete(k);
    }
  }
}
