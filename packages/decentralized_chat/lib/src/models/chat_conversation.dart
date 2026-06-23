import 'chat_message.dart';

class ChatConversation {
  final String id;
  final String type;
  final List<String> participantAddresses;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final int epoch;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  const ChatConversation({
    required this.id,
    required this.type,
    required this.participantAddresses,
    this.lastMessage,
    this.unreadCount = 0,
    this.epoch = 0,
    required this.createdAt,
    this.lastActiveAt,
  });

  ChatConversation copyWith({
    ChatMessage? lastMessage,
    int? unreadCount,
    int? epoch,
    DateTime? lastActiveAt,
  }) {
    return ChatConversation(
      id: id,
      type: type,
      participantAddresses: participantAddresses,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      epoch: epoch ?? this.epoch,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'participant_addresses': participantAddresses,
    'last_message': lastMessage?.toJson(),
    'unread_count': unreadCount,
    'epoch': epoch,
    'created_at': createdAt.toIso8601String(),
    'last_active_at': lastActiveAt?.toIso8601String(),
  };

  factory ChatConversation.fromJson(Map<String, dynamic> json) => ChatConversation(
    id: json['id'] as String,
    type: json['type'] as String,
    participantAddresses: (json['participant_addresses'] as List)
        .map((e) => e as String)
        .toList(),
    lastMessage: json['last_message'] != null
        ? ChatMessage.fromJson(json['last_message'] as Map<String, dynamic>)
        : null,
    unreadCount: json['unread_count'] as int? ?? 0,
    epoch: json['epoch'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
    lastActiveAt: json['last_active_at'] != null
        ? DateTime.parse(json['last_active_at'] as String)
        : null,
  );
}
