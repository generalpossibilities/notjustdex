import 'dart:convert';
import 'package:hive/hive.dart';

const String _auditBox = 'vault_audit';

enum AuditAction {
  view,
  create,
  update,
  delete,
  unlock,
  lock,
  exportBackup,
  importBackup,
  sync,
  syncFailed,
  biometricGate,
  clipboardCopy,
}

class AuditEntry {
  final AuditAction action;
  final String? entryId;
  final String? entryName;
  final int timestamp;
  final bool success;
  final String? details;

  const AuditEntry({
    required this.action,
    this.entryId,
    this.entryName,
    required this.timestamp,
    this.success = true,
    this.details,
  });

  Map<String, dynamic> toJson() => {
        'action': action.name,
        'entryId': entryId,
        'entryName': entryName,
        'timestamp': timestamp,
        'success': success,
        if (details != null) 'details': details,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        action: AuditAction.values.firstWhere(
          (a) => a.name == json['action'],
          orElse: () => AuditAction.view,
        ),
        entryId: json['entryId'] as String?,
        entryName: json['entryName'] as String?,
        timestamp: json['timestamp'] as int,
        success: json['success'] as bool? ?? true,
        details: json['details'] as String?,
      );
}

class VaultAuditService {
  late final Box _box;
  bool _initialized = false;

  static const int _maxEntries = 1000;

  Future<void> init() async {
    if (!_initialized) {
      _box = await Hive.openBox(_auditBox);
      _initialized = true;
    }
  }

  Future<void> log(AuditEntry entry) async {
    if (!_initialized) await init();
    final key = entry.timestamp.toString();
    await _box.put(key, entry.toJson());
    await _trim();
  }

  Future<void> logView(String entryId, String entryName) async {
    await log(AuditEntry(
      action: AuditAction.view,
      entryId: entryId,
      entryName: entryName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> logCreate(String entryId, String entryName) async {
    await log(AuditEntry(
      action: AuditAction.create,
      entryId: entryId,
      entryName: entryName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> logUpdate(String entryId, String entryName) async {
    await log(AuditEntry(
      action: AuditAction.update,
      entryId: entryId,
      entryName: entryName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> logDelete(String entryId, String entryName) async {
    await log(AuditEntry(
      action: AuditAction.delete,
      entryId: entryId,
      entryName: entryName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> logUnlock() async {
    await log(AuditEntry(
      action: AuditAction.unlock,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> logLock() async {
    await log(AuditEntry(
      action: AuditAction.lock,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> logBiometricGate(bool success) async {
    await log(AuditEntry(
      action: AuditAction.biometricGate,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      success: success,
      details: success ? null : 'Biometric verification failed',
    ));
  }

  Future<List<AuditEntry>> getLog({int limit = 50}) async {
    if (!_initialized) await init();
    final keys = _box.keys.cast<String>().toList()
      ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));
    final entries = <AuditEntry>[];
    for (final key in keys.take(limit)) {
      final data = _box.get(key) as Map<String, dynamic>?;
      if (data != null) {
        entries.add(AuditEntry.fromJson(data));
      }
    }
    return entries;
  }

  Future<void> clearLog() async {
    if (!_initialized) await init();
    await _box.clear();
  }

  Future<void> _trim() async {
    final count = _box.length;
    if (count > _maxEntries) {
      final keys = _box.keys.cast<String>().toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      final toDelete = keys.take(count - _maxEntries);
      for (final key in toDelete) {
        await _box.delete(key);
      }
    }
  }
}
