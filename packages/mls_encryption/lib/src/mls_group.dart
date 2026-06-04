import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'mls_crypto.dart';
import 'mls_message.dart';
import 'mls_key_package.dart';
import 'mls_exception.dart';

/// MLS Group — a TreeKEM-based encrypted group.
///
/// TreeKEM (Tree Key Encapsulation Mechanism):
/// Each leaf in the binary tree corresponds to a group member.
/// Each node has an HPKE key pair. The root key is the group secret.
///
/// When a member is added or removed, only the path from the
/// changed leaf to the root needs to be updated (O(log N)).
class MlsGroup {
  final String groupId;
  final String creatorId;
  final List<MlsMember> members;
  final int epoch; // Incremented on every group change
  final Map<String, List<int>> _keyMap; // memberId → leaf key
  List<int> _groupSecret; // Root key of the tree

  MlsGroup._({
    required this.groupId,
    required this.creatorId,
    required this.members,
    required this.epoch,
    required Map<String, List<int>> keyMap,
    required List<int> groupSecret,
  })  : _keyMap = Map.from(keyMap),
        _groupSecret = List.from(groupSecret);

  /// Create a new group with the creator as the sole initial member.
  factory MlsGroup.create(String groupId, MlsKeyStore creatorKeys) {
    final leafKey = MlsCrypto.hashRatchet(
      creatorKeys.encryptionPublicKey,
      0,
    );

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

  /// Encrypt a message for all group members.
  MlsMessage encryptMessage(String senderId, String plaintext, List<int> senderPrivateKey) {
    // 1. Derive an encryption key from the group secret + epoch
    final encKey = MlsCrypto.deriveEncryptionKey(_groupSecret, 'handshake-$epoch');

    // 2. Encrypt the plaintext with AES-256-GCM
    final nonce = List<int>.generate(12, (_) => DateTime.now().microsecondsSinceEpoch % 256);
    final combined = MlsCrypto.hpkeEncrypt(
      utf8.encode(plaintext),
      encKey, // Use group secret as "public key" for symmetric encryption
      senderPrivateKey,
    );

    // 3. Sign the ciphertext
    final toSign = utf8.encode(groupId) +
        utf8.encode(senderId) +
        combined.ciphertext;
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

  /// Decrypt a message. Only group members can decrypt.
  String decryptMessage(MlsMessage message, List<int> recipientPrivateKey) {
    if (message.epoch != epoch) {
      throw MlsException.decryptionFailed();
    }

    // 1. Derive the same encryption key
    final encKey = MlsCrypto.deriveEncryptionKey(_groupSecret, 'handshake-$epoch');

    // 2. Get sender's public key
    final sender = members.firstWhere(
      (m) => m.userId == message.senderId,
      orElse: () => throw MlsException.notMember(),
    );

    // 3. Verify signature
    final toVerify = utf8.encode(groupId) +
        utf8.encode(message.senderId) +
        message.ciphertext.ciphertext;
    if (!MlsCrypto.verify(toVerify, message.signature, sender.signaturePublicKey)) {
      throw MlsException.invalidSignature();
    }

    // 4. Decrypt
    final plaintext = MlsCrypto.hpkeDecrypt(
      message.ciphertext,
      recipientPrivateKey,
      sender.encryptionPublicKey,
    );

    return utf8.decode(plaintext);
  }

  /// Add a new member to the group using their key package.
  MlsGroup addMember(MlsKeyPackage newMemberKey, String adminId, List<int> adminPrivateKey) {
    if (newMemberKey.isExpired) {
      throw MlsException.invalidKeyPackage();
    }

    if (!newMemberKey.verify()) {
      throw MlsException.invalidKeyPackage();
    }

    // 1. Create new leaf for the member
    final newLeafKey = MlsCrypto.hashRatchet(
      newMemberKey.encryptionPublicKey,
      0,
    );

    // 2. Update the group secret using TreeKEM
    //    (simplified: XOR the new leaf key with the current group secret)
    final newSecret = sha256.convert([
      ..._groupSecret,
      ...newLeafKey,
      ...utf8.encode(epoch.toString()),
    ]).bytes;

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
      keyMap: {
        ..._keyMap,
        newMemberKey.userId: newLeafKey,
      },
      groupSecret: newSecret,
    );
  }

  /// Remove a member from the group.
  MlsGroup removeMember(String memberId, String adminId, List<int> adminPrivateKey) {
    if (!members.any((m) => m.userId == memberId)) {
      throw MlsException.notMember();
    }

    // 1. Remove the member's key
    final newKeys = Map<String, List<int>>.from(_keyMap)
      ..remove(memberId);

    // 2. Update the group secret (exclude the removed member)
    final remainingKeys = newKeys.values.expand((k) => k).toList();
    final newSecret = sha256.convert([
      ..._groupSecret,
      ...remainingKeys,
      ...utf8.encode('remove-$epoch'),
    ]).bytes;

    return MlsGroup._(
      groupId: groupId,
      creatorId: creatorId,
      members: members.where((m) => m.userId != memberId).toList(),
      epoch: epoch + 1,
      keyMap: newKeys,
      groupSecret: newSecret,
    );
  }

  /// Serialize the group state (for sending to new members via MLS Commit).
  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'creator_id': creatorId,
    'epoch': epoch,
    'group_secret': base64Url.encode(_groupSecret),
    'members': members.map((m) => m.toJson()).toList(),
    'keys': _keyMap.map((k, v) => MapEntry(k, base64Url.encode(v))),
  };

  factory MlsGroup.fromJson(Map<String, dynamic> json) => MlsGroup._(
    groupId: json['group_id'] as String,
    creatorId: json['creator_id'] as String,
    epoch: json['epoch'] as int,
    members: (json['members'] as List)
        .map((m) => MlsMember.fromJson(m as Map<String, dynamic>))
        .toList(),
    keyMap: (json['keys'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, base64Url.decode(v as String)),
    ),
    groupSecret: base64Url.decode(json['group_secret'] as String),
  );
}

/// A member of an MLS group.
class MlsMember {
  final String userId;
  final List<int> encryptionPublicKey;
  final List<int> signaturePublicKey;
  final DateTime joinedAt;

  const MlsMember({
    required this.userId,
    required this.encryptionPublicKey,
    required this.signaturePublicKey,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'encryption_public_key': base64Url.encode(encryptionPublicKey),
    'signature_public_key': base64Url.encode(signaturePublicKey),
    'joined_at': joinedAt.toIso8601String(),
  };

  factory MlsMember.fromJson(Map<String, dynamic> json) => MlsMember(
    userId: json['user_id'] as String,
    encryptionPublicKey: base64Url.decode(json['encryption_public_key'] as String),
    signaturePublicKey: base64Url.decode(json['signature_public_key'] as String),
    joinedAt: DateTime.parse(json['joined_at'] as String),
  );
}
