import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Manages JWT session persistence and offline caching.
/// JWT expires in 7 days; cached locally for 24h offline use.
class SessionService {
  // In production: store in flutter_secure_storage + Hive/Isar
  String? _token;
  String? _userId;
  String? _username;
  String? _displayName;
  String? _phoneNumber;
  DateTime? _lastSync;

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  String? get userId => _userId;
  String? get username => _username;
  String? get displayName => _displayName;
  String? get phoneNumber => _phoneNumber;

  /// Check for existing session on app start.
  /// Returns true if valid session found.
  Future<bool> tryRestore() async {
    // Stub: simulate checking secure storage for cached JWT
    // In production: decrypt from secure storage, validate expiry, return true if valid
    await Future.delayed(const Duration(milliseconds: 100));
    return _token != null;
  }

  /// Save session after successful auth.
  Future<void> saveSession({
    required String token,
    required String userId,
    required String username,
    String? displayName,
    String? phoneNumber,
  }) async {
    _token = token;
    _userId = userId;
    _username = username;
    _displayName = displayName;
    _phoneNumber = phoneNumber;
    _lastSync = DateTime.now();

    // In production: encrypt and persist to flutter_secure_storage
    debugPrint('[Session] Saved session for $username');
  }

  /// Clear session (sign out).
  Future<void> clearSession() async {
    _token = null;
    _userId = null;
    _username = null;
    _displayName = null;
    _phoneNumber = null;
    _lastSync = null;

    // In production: clear secure storage
    debugPrint('[Session] Cleared session');
  }

  /// Update display name in cached session.
  void updateDisplayName(String name) {
    _displayName = name;
  }
}
