import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'mls_crypto.dart';
import 'mls_message.dart';
import 'mls_key_package.dart';
import 'mls_exception.dart';

/// MLS Group — TreeKEM-based encrypted group.
class MlsGroup {
  final String groupId;
  final String creatorId;
  final List<MlsMember> members;
  final int epoch;
  final Map<String, Uint8List> _keyMap;
  Uint8List _groupSecret;

  MlsGroup._({
    required this.groupId,
    required this.creatorId,
    required this.members,
    required this.epoch,
    required Map<String, Uint8List> keyMap,
    required Uint8List groupSecret,
  })  : _keyMap = Map.from(keyMap),
        _groupSecret = groupSecret;

  factory MlsGroup.create(String groupId, MlsKeyStore creatorKeys) {
    final leafKey = MlsCrypto.hashRatchet(creatorKeys.encryptionPublicKey, 0);

    return MlsGroup._(
      groupId: groupId,
      creatorId: creatorKeys.userId,
      members: [
        MlsMember(
          userId: creatorKeys.userId,
          encryptionPublicKey: creatorKeys.encryptionPublicKey,
          signaturePublicKey: creatorKeys.signaturePublicKey,
          joinedAt: DateTime.now(),
        ),
      ],
      epoch: 0,
      keyMap: {creatorKeys.userId: leafKey},
      groupSecret: leafKey,
    );
  }

  MlsMessage encryptMessage(
      String senderId, String plaintext, Uint8List senderPrivateKey) {
    final encKey = MlsCrypto.deriveEncryptionKey(_groupSecret, 'handshake-$epoch');
    final combined = MlsCrypto.hpkeEncrypt(
      Uint8List.fromList(utf8.encode(plaintext)),
      encKey,
      senderPrivateKey,
    );

    final toSign = Uint8List.fromList(
      utf8.encode(groupId) + utf8.encode(senderId) + combined.ciphertext.toList(),
    );
    final signature = MlsCrypto.sign(toSign, senderPrivateKey);

    return MlsMessage(
      groupId: groupId,
      senderId: senderId,
      epoch: epoch,
      ciphertext: combined,
      signature: signature,
      messageType: MessageType.application,
    );
  }

  String decryptMessage(MlsMessage message, Uint8List recipientPrivateKey) {
    if (message.epoch != epoch) {
      throw MlsException.decryptionFailed();
    }

    final sender = members.firstWhere(
      (m) => m.userId == message.senderId,
      orElse: () => throw MlsException.notMember(),
    );

    final toVerify = Uint8List.fromList(
      utf8.encode(groupId) +
          utf8.encode(message.senderId) +
          message.ciphertext.ciphertext.toList(),
    );
    if (!MlsCrypto.verify(toVerify, message.signature, sender.signaturePublicKey)) {
      throw MlsException.invalidSignature();
    }

    final plaintext = MlsCrypto.hpkeDecrypt(
      message.ciphertext,
      recipientPrivateKey,
      sender.encryptionPublicKey,
    );

    return utf8.decode(plaintext.toList());
  }

  MlsGroup addMember(MlsKeyPackage newMemberKey, String adminId, Uint8List adminPrivateKey) {
    if (newMemberKey.isExpired) throw MlsException.invalidKeyPackage();
    if (!newMemberKey.verify()) throw MlsException.invalidKeyPackage();

    final newLeafKey = MlsCrypto.hashRatchet(newMemberKey.encryptionPublicKey, 0);
    final newSecret = Uint8List.fromList(sha256.convert(
      Uint8List.fromList([
        ..._groupSecret.toList(),
        ...newLeafKey.toList(),
        ...utf8.encode(epoch.toString()),
      ]),
    ).bytes);

    return MlsGroup._(
      groupId: groupId,
      creatorId: creatorId,
      members: [
        ...members,
        MlsMember(
          userId: newMemberKey.userId,
          encryptionPublicKey: newMemberKey.encryptionPublicKey,
          signaturePublicKey: newMemberKey.signaturePublicKey,
          joinedAt: DateTime.now(),
        ),
      ],
      epoch: epoch + 1,
      keyMap: {..._keyMap, newMemberKey.userId: newLeafKey},
      groupSecret: newSecret,
    );
  }

  MlsGroup removeMember(String memberId, String adminId, Uint8List adminPrivateKey) {
    if (!members.any((m) => m.userId == memberId)) {
      throw MlsException.notMember();
    }

    final newKeys = Map<String, Uint8List>.from(_keyMap)..remove(memberId);
    final remainingKeys = newKeys.values.expand((k) => k.toList()).toList();
    final newSecret = Uint8List.fromList(sha256.convert(
      Uint8List.fromList([
        ..._groupSecret.toList(),
        ...remainingKeys,
        ...utf8.encode('remove-$epoch'),
      ]),
    ).bytes);

    return MlsGroup._(
      groupId: groupId,
      creatorId: creatorId,
      members: members.where((m) => m.userId != memberId).toList(),
      epoch: epoch + 1,
      keyMap: newKeys,
      groupSecret: newSecret,
    );
  }

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'creator_id': creatorId,
    'epoch': epoch,
    'group_secret': base64Url.encode(_groupSecret.toList()),
    'members': members.map((m) => m.toJson()).toList(),
    'keys': _keyMap.map((k, v) => MapEntry(k, base64Url.encode(v.toList()))),
  };

  factory MlsGroup.fromJson(Map<String, dynamic> json) => MlsGroup._(
    groupId: json['group_id'] as String,
    creatorId: json['creator_id'] as String,
    epoch: json['epoch'] as int,
    members: (json['members'] as List)
        .map((m) => MlsMember.fromJson(m as Map<String, dynamic>))
        .toList(),
    keyMap: (json['keys'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, Uint8List.fromList(base64Url.decode(v as String))),
    ),
    groupSecret: Uint8List.fromList(base64Url.decode(json['group_secret'] as String)),
  );
}

class MlsMember {
  final String userId;
  final Uint8List encryptionPublicKey;
  final Uint8List signaturePublicKey;
  final DateTime joinedAt;

  const MlsMember({
    required this.userId,
    required this.encryptionPublicKey,
    required this.signaturePublicKey,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'encryption_public_key': base64Url.encode(encryptionPublicKey.toList()),
    'signature_public_key': base64Url.encode(signaturePublicKey.toList()),
    'joined_at': joinedAt.toIso8601String(),
  };

  factory MlsMember.fromJson(Map<String, dynamic> json) => MlsMember(
    userId: json['user_id'] as String,
    encryptionPublicKey: Uint8List.fromList(base64Url.decode(json['encryption_public_key'] as String)),
    signaturePublicKey: Uint8List.fromList(base64Url.decode(json['signature_public_key'] as String)),
    joinedAt: DateTime.parse(json['joined_at'] as String),
  );
}
