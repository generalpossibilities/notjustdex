/// A message in a decentralized chat conversation.
///
/// Content is MLS-encrypted at rest and in transit.
/// The relay never sees plaintext content.
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderAddress;
  final String content;
  final String contentType;
  final int epoch;
  final DateTime sentAt;
  final bool isMe;
  final bool isPending;
  final String? replyToId;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderAddress,
    required this.content,
    this.contentType = 'text',
    this.epoch = 0,
    required this.sentAt,
    this.isMe = false,
    this.isPending = false,
    this.replyToId,
  });

  ChatMessage copyWith({
    bool? isPending,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderAddress: senderAddress,
      content: content,
      contentType: contentType,
      epoch: epoch,
      sentAt: sentAt,
      isMe: isMe,
      isPending: isPending ?? this.isPending,
      replyToId: replyToId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'sender_address': senderAddress,
    'content': content,
    'content_type': contentType,
    'epoch': epoch,
    'sent_at': sentAt.toIso8601String(),
    'is_me': isMe,
    'is_pending': isPending,
    'reply_to_id': replyToId,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    conversationId: json['conversation_id'] as String,
    senderAddress: json['sender_address'] as String,
    content: json['content'] as String,
    contentType: json['content_type'] as String? ?? 'text',
    epoch: json['epoch'] as int? ?? 0,
    sentAt: DateTime.parse(json['sent_at'] as String),
    isMe: json['is_me'] as bool? ?? false,
    isPending: json['is_pending'] as bool? ?? false,
    replyToId: json['reply_to_id'] as String?,
  );
}
