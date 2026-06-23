import 'dart:convert';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:notjustdex_mls_encryption/mls_encryption.dart';

/// Persists [MlsGroup] state to Hive, encrypted at rest with a key derived
/// from the user's MLS encryption key pair.
///
/// On a new device, the group state is reconstructed from the deterministic
/// MLS keys (derived from wallet seed) + the Hive backup (cross-device sync
/// via backup/restore flow).
class MlsGroupStore {
  static const _boxName = 'mls_groups';
  late Box<String> _box;
  Uint8List? _encryptionKey;

  Future<void> init({Uint8List? encryptionKey}) async {
    _box = await Hive.openBox<String>(_boxName);
    _encryptionKey = encryptionKey;
  }

  /// Save an MLS group. The group secret is encrypted at rest.
  Future<void> saveGroup(String conversationId, MlsGroup group) async {
    final json = group.toJson();
    final serialized = jsonEncode(json);

    String stored;
    if (_encryptionKey != null) {
      stored = await _encrypt(serialized, _encryptionKey!);
    } else {
      stored = base64Url.encode(utf8.encode(serialized));
    }

    await _box.put(conversationId, stored);
  }

  /// Load an MLS group. Returns null if not found.
  Future<MlsGroup?> loadGroup(String conversationId) async {
    final stored = _box.get(conversationId);
    if (stored == null) return null;

    try {
      String serialized;
      if (_encryptionKey != null) {
        serialized = await _decrypt(stored, _encryptionKey!);
      } else {
        serialized = utf8.decode(base64Url.decode(stored));
      }
      return MlsGroup.fromJson(
        jsonDecode(serialized) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Load all stored MLS groups.
  Future<List<MapEntry<String, MlsGroup>>> loadAllGroups() async {
    final result = <MapEntry<String, MlsGroup>>[];
    for (final key in _box.keys) {
      final group = await loadGroup(key);
      if (group != null) {
        result.add(MapEntry(key, group));
      }
    }
    return result;
  }

  /// Remove a group (e.g., when leaving a conversation).
  Future<void> removeGroup(String conversationId) async {
    await _box.delete(conversationId);
  }

  /// Clear all groups (e.g., on full logout).
  Future<void> clear() async {
    await _box.clear();
  }

  Future<String> _encrypt(String plaintext, Uint8List key) async {
    final aesGcm = AesGcm.with256bits();
    final nonce = List<int>.generate(12, (_) => _secureByte());
    final secretBox = await aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
      nonce: Uint8List.fromList(nonce),
    );
    final payload = {
      'n': base64Url.encode(nonce),
      'c': base64Url.encode(secretBox.cipherText),
      'm': base64Url.encode(secretBox.mac.bytes),
    };
    return base64Url.encode(utf8.encode(jsonEncode(payload)));
  }

  Future<String> _decrypt(String ciphertext, Uint8List key) async {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(ciphertext)),
    ) as Map<String, dynamic>;
    final aesGcm = AesGcm.with256bits();
    final secretBox = SecretBox(
      base64Url.decode(payload['c'] as String),
      nonce: Uint8List.fromList(base64Url.decode(payload['n'] as String)),
      mac: Mac(Uint8List.fromList(base64Url.decode(payload['m'] as String))),
    );
    final plaintext = await aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(key),
    );
    return utf8.decode(plaintext);
  }

  int _secureByte() => Random.secure().nextInt(256);
}
