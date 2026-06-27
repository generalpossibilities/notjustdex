import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

const _boxName = 'session';

class SessionService {
  late Box _box;
  bool _initialized = false;

  bool get isLoggedIn => _get('token') != null;
  String? get token => _get('token');
  String? get userId => _get('userId');
  String? get username => _get('username');
  String? get walletAddress => _get('walletAddress');
  String? get displayName => _get('displayName');
  String? get phoneNumber => _get('phoneNumber');
  bool get isIdentityComplete => username != null && username!.isNotEmpty && walletAddress != null && walletAddress!.isNotEmpty;

  String? _get(String key) {
    if (!_initialized) return null;
    return _box.get(key) as String?;
  }

  Future<bool> tryRestore() async {
    try {
      _box = await Hive.openBox(_boxName);
      _initialized = true;
      return _box.get('token') != null;
    } catch (e) {
      debugPrint('[Session] Failed to open Hive box: $e');
      return false;
    }
  }

  Future<void> saveSession({
    required String token,
    required String userId,
    required String username,
    String? walletAddress,
    String? displayName,
    String? phoneNumber,
  }) async {
    if (!_initialized) return;
    await _box.putAll({
      'token': token,
      'userId': userId,
      'username': username,
      if (walletAddress != null) 'walletAddress': walletAddress,
      if (displayName != null) 'displayName': displayName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    });
    debugPrint('[Session] Saved session for $username');
  }

  Future<void> clearSession() async {
    if (!_initialized) return;
    await _box.clear();
    debugPrint('[Session] Cleared session');
  }

  Future<void> updateDisplayName(String name) async {
    if (!_initialized) return;
    await _box.put('displayName', name);
  }
}
