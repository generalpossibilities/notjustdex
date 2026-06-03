import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String contentType;
  final DateTime sentAt;
  final String? replyToId;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.contentType = 'text',
    required this.sentAt,
    this.replyToId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        senderId: json['sender_id'] as String,
        content: json['content'] as String,
        contentType: json['content_type'] as String? ?? 'text',
        sentAt: DateTime.parse(json['sent_at'] as String),
        replyToId: json['reply_to_id'] as String?,
      );
}

class ChatConversation {
  final String id;
  final String type;
  final List<String> participantIds;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime createdAt;

  ChatConversation({
    required this.id,
    required this.type,
    required this.participantIds,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      ChatConversation(
        id: json['id'] as String,
        type: json['type'] as String,
        participantIds: (json['participant_ids'] as List)
            .map((e) => e as String)
            .toList(),
        lastMessage: json['last_message'] != null
            ? ChatMessage.fromJson(json['last_message'] as Map<String, dynamic>)
            : null,
        unreadCount: json['unread_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class ChatClient {
  WebSocket? _ws;
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Future<void> connect(String userId, String host) async {
    _ws = await WebSocket.connect('ws://$host/ws?user_id=$userId');
    _ws!.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        final type = json['type'] as String;
        if (type == 'new_message') {
          _messageController.add(
            ChatMessage.fromJson(json['message'] as Map<String, dynamic>),
          );
        } else {
          _eventController.add(json);
        }
      },
      onError: (e) => print('WebSocket error: $e'),
      onDone: () => print('WebSocket closed'),
    );
  }

  void sendMessage(String conversationId, String content,
      {String contentType = 'text'}) {
    final msg = jsonEncode({
      'type': 'send_message',
      'conversation_id': conversationId,
      'content': content,
      'content_type': contentType,
    });
    _ws?.add(msg);
  }

  void sendTyping(String conversationId) {
    final msg = jsonEncode({
      'type': 'typing',
      'conversation_id': conversationId,
    });
    _ws?.add(msg);
  }

  void disconnect() {
    _ws?.close();
    _messageController.close();
    _eventController.close();
  }
}
