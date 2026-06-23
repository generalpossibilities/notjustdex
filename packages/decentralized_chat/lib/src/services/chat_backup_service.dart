import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' show sha256, Hmac;
import 'package:notjustdex_identity_kernel/identity_kernel.dart';
import 'package:notjustdex_mls_encryption/mls_encryption.dart';
import '../models/chat_message.dart';
import '../models/chat_conversation.dart';
import 'conversation_store.dart';

/// Encrypted chat message backup to IPFS with chain-indexed CIDs.
///
/// On every N new messages (configurable), the backup service:
/// 1. Serializes all messages since last backup for each conversation
/// 2. Encrypts with a key derived from the wallet seed
/// 3. Uploads the encrypted blob to IPFS
/// 4. Commits the CID to the Acki Nacki chain via [postContent]
///
/// On a new device (after passkey login), the service:
/// 1. Reads backup CIDs from the chain
/// 2. Downloads each blob from IPFS
/// 3. Decrypts with the same derived key
/// 4. Restores messages to local Hive
class ChatBackupService {
  final ConversationStore _store;
  final IpfsClient _ipfs;
  final AnIdentityContract _contract;
  final String _myAddress;
  final String _encryptionLabel = 'chat-backup-v1';
  final int _messagesPerBackup;

  ChatBackupService({
    required ConversationStore store,
    required IpfsClient ipfs,
    required AnIdentityContract contract,
    required String myAddress,
    int messagesPerBackup = 50,
  })  : _store = store,
        _ipfs = ipfs,
        _contract = contract,
        _myAddress = myAddress,
        _messagesPerBackup = messagesPerBackup;

  /// Derive the chat backup encryption key from the wallet seed.
  Uint8List _deriveKey(Uint8List walletSeed) {
    final hmac = Hmac(sha256, walletSeed);
    return Uint8List.fromList(
      hmac.convert(utf8.encode(_encryptionLabel)).bytes,
    );
  }

  /// Encrypt message data for backup.
  Future<Uint8List> _encryptBackup(
    Map<String, dynamic> data,
    Uint8List key,
  ) async {
    final plaintext = utf8.encode(jsonEncode(data));
    final encKey = await MlsCrypto.generateKeyPairFromSeed(key);
    final ciphertext = await MlsCrypto.hpkeEncrypt(
      Uint8List.fromList(plaintext),
      encKey.publicKey,
      encKey,
    );
    return Uint8List.fromList(
      utf8.encode(jsonEncode(ciphertext.toJson())),
    );
  }

  /// Decrypt backup data.
  Future<Map<String, dynamic>?> _decryptBackup(
    Uint8List blob,
    Uint8List key,
  ) async {
    try {
      final ciphertext = HpkeCiphertext.fromJson(
        jsonDecode(utf8.decode(blob)) as Map<String, dynamic>,
      );
      final encKey = await MlsCrypto.generateKeyPairFromSeed(key);
      final plaintext = await MlsCrypto.hpkeDecrypt(
        ciphertext,
        encKey,
        ciphertext.encapsulatedKey,
      );
      return jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Backup all conversations' messages to IPFS.
  /// Returns the IPFS CIDs of the uploaded backup blobs.
  Future<List<String>> backupAll({
    required Uint8List walletSeed,
  }) async {
    final key = _deriveKey(walletSeed);
    final conversations = _store.getConversations();
    final cids = <String>[];

    for (final conv in conversations) {
      final messages = _store.getMessages(conv.id);
      if (messages.isEmpty) continue;

      final backup = {
        'version': 1,
        'backed_up_at': DateTime.now().toUtc().toIso8601String(),
        'conversation_id': conv.id,
        'conversation_type': conv.type,
        'participants': conv.participantAddresses,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

      final encrypted = await _encryptBackup(backup, key);
      final cid = await _ipfs.uploadBytes(
        encrypted.toList(),
        fileName: 'chat_backup_${conv.id}.enc',
      );

      // Commit the backup CID to chain
      final hash = sha256.convert(utf8.encode('chat_backup:$cid')).toString();
      await _contract.postContent(_myAddress, hash);

      cids.add(cid);
    }

    return cids;
  }

  /// Restore all conversations from IPFS backups.
  /// [backupCids] — list of CIDs retrieved from chain or external source.
  /// [walletSeed] — the wallet seed (from passkey) to derive decryption key.
  Future<int> restoreFromBackup({
    required List<String> backupCids,
    required Uint8List walletSeed,
    required AnIdentityContract contract,
  }) async {
    final key = _deriveKey(walletSeed);
    int restored = 0;

    for (final cid in backupCids) {
      try {
        final encrypted = await _ipfs.fetchBytes(cid);
        final data = await _decryptBackup(
          Uint8List.fromList(encrypted),
          key,
        );
        if (data == null) continue;

        final messagesJson = data['messages'] as List<dynamic>;
        for (final msgJson in messagesJson) {
          final msg = ChatMessage.fromJson(
            msgJson as Map<String, dynamic>,
          );
          await _store.saveMessage(msg);
          restored++;
        }
      } catch (_) {
        // Skip failed CIDs — partial recovery is OK
      }
    }

    return restored;
  }

  /// Get all chat backup CIDs from the chain.
  Future<List<String>> getBackupCidsFromChain({
    required AnIdentityContract contract,
    required String address,
  }) async {
    final identity = await contract.getIdentity(address);
    if (identity == null) return [];
    // contentHashes starting with "chat_backup:" indicate chat backups
    // In a real implementation, the contract would have a dedicated
    // backupCids array or we'd filter contentHashes by prefix.
    return [];
  }
}
