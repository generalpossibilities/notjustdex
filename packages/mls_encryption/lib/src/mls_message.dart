import 'dart:convert';
import 'mls_crypto.dart';

enum MessageType { application, proposal, commit }

/// An MLS-encrypted message.
class MlsMessage {
  final String groupId;
  final String senderId;
  final int epoch;
  final HpkeCiphertext ciphertext;
  final List<int> signature;
  final MessageType messageType;

  const MlsMessage({
    required this.groupId,
    required this.senderId,
    required this.epoch,
    required this.ciphertext,
    required this.signature,
    this.messageType = MessageType.application,
  });

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'sender_id': senderId,
    'epoch': epoch,
    'ciphertext': ciphertext.toJson(),
    'signature': base64Url.encode(signature),
    'message_type': messageType.name,
  };

  factory MlsMessage.fromJson(Map<String, dynamic> json) => MlsMessage(
    groupId: json['group_id'] as String,
    senderId: json['sender_id'] as String,
    epoch: json['epoch'] as int,
    ciphertext: HpkeCiphertext.fromJson(
      json['ciphertext'] as Map<String, dynamic>,
    ),
    signature: base64Url.decode(json['signature'] as String),
    messageType: MessageType.values.firstWhere(
      (t) => t.name == json['message_type'],
      orElse: () => MessageType.application,
    ),
  );
}
