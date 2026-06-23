import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import '../services/wallet_service.dart';
import '../services/acki_nacki_client.dart';
import '../exceptions.dart';
import 'models/vault_entry.dart';
import 'models/vault_config.dart';
import 'models/vault_entry_type.dart';
import 'crypto/key_derivation.dart';
import 'crypto/vault_crypto.dart';
import 'crypto/password_generator.dart';
import 'storage/vault_storage.dart';
import 'services/vault_audit_service.dart';
import 'services/vault_backup_service.dart';

class VaultException implements Exception {
  final String message;
  const VaultException(this.message);
  @override
  String toString() => 'VaultException: $message';
}

class VaultService {
  final String username;
  final WalletService _walletService;
  final String _identityId;
  final VaultStorage _chainStorage;
  final VaultStorage _localStorage;
  final VaultAuditService _audit;
  final VaultBackupService _backup;
  final PasswordGenerator _passwordGenerator;

  List<VaultEntry> _cache = [];
  VaultConfig _config = const VaultConfig();
  VaultKey? _currentKey;
  bool _isUnlocked = false;

  VaultService({
    required this.username,
    required WalletService walletService,
    required String identityId,
    required VaultStorage chainStorage,
    required VaultStorage localStorage,
    VaultAuditService? audit,
    VaultBackupService? backup,
    PasswordGenerator? passwordGenerator,
  })  : _walletService = walletService,
        _identityId = identityId,
        _chainStorage = chainStorage,
        _localStorage = localStorage,
        _audit = audit ?? VaultAuditService(),
        _backup = backup ?? VaultBackupService(),
        _passwordGenerator = passwordGenerator ?? PasswordGenerator();

  VaultConfig get config => _config;
  bool get isUnlocked => _isUnlocked;
  List<VaultEntry> get cachedEntries => List.unmodifiable(_cache);

  Future<void> init() async {
    await _audit.init();
  }

  Future<bool> unlock({String? saltPassword}) async {
    try {
      final key = await deriveVaultKey(
        username: username,
        saltPassword: saltPassword,
      );

      final chainData = await _chainStorage.read();
      final localData = await _localStorage.read();

      List<VaultEntry>? entries;

      if (chainData != null) {
        final encrypted = deserializeVault(chainData);
        entries = await decryptVault(encrypted, key.encryptionKey);
        if (entries != null) {
          _cache = entries;
          _currentKey = key;
          _isUnlocked = true;
          if (localData == null) {
            await _localStorage.write(chainData);
          }
          await _audit.logUnlock();
          return true;
        }
      }

      if (localData != null) {
        final encrypted = deserializeVault(localData);
        entries = await decryptVault(encrypted, key.encryptionKey);
        if (entries != null) {
          _cache = entries;
          _currentKey = key;
          _isUnlocked = true;
          await _audit.logUnlock();
          return true;
        }
      }

      _cache = [];
      _currentKey = key;
      _isUnlocked = true;
      await _audit.logUnlock();
      return true;
    } catch (_) {
      _isUnlocked = false;
      return false;
    }
  }

  void lock() {
    _isUnlocked = false;
    _currentKey = null;
    _audit.logLock();
  }

  Future<void> saveVault({String? signedMessage}) async {
    _requireUnlocked();
    if (_currentKey == null) {
      throw VaultException('Vault is not unlocked');
    }

    final encrypted = await encryptVault(_cache, _currentKey!.encryptionKey);
    final serialized = serializeVault(encrypted);

    await _localStorage.write(serialized);

    if (signedMessage != null) {
      await _chainStorage.write(serialized);
    }
  }

  Future<List<VaultEntry>> loadVault({String? saltPassword}) async {
    final unlocked = await unlock(saltPassword: saltPassword);
    if (!unlocked) {
      throw VaultException('Failed to unlock vault');
    }
    return List.unmodifiable(_cache);
  }

  Future<VaultEntry> addEntry({
    required String name,
    required VaultEntryType type,
    Map<String, String> fields = const {},
    String? notes,
    List<String> tags = const [],
  }) async {
    _requireUnlocked();
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _generateId();

    final entry = VaultEntry(
      id: id,
      type: type,
      name: name,
      fields: fields,
      notes: notes,
      tags: tags,
      createdAt: now,
      updatedAt: now,
      version: 1,
    );

    _cache.add(entry);
    await _audit.logCreate(id, name);
    return entry;
  }

  Future<VaultEntry> updateEntry(VaultEntry entry) async {
    _requireUnlocked();
    final index = _cache.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      throw VaultException('Entry not found: ${entry.id}');
    }

    final updated = entry.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      version: entry.version + 1,
    );

    _cache[index] = updated;
    await _audit.logUpdate(entry.id, entry.name);
    return updated;
  }

  Future<void> deleteEntry(String entryId) async {
    _requireUnlocked();
    final index = _cache.indexWhere((e) => e.id == entryId);
    if (index == -1) {
      throw VaultException('Entry not found: $entryId');
    }
    final entry = _cache[index];
    _cache.removeAt(index);
    await _audit.logDelete(entryId, entry.name);
  }

  VaultEntry? getEntry(String entryId) {
    _requireUnlocked();
    return _cache.where((e) => e.id == entryId).firstOrNull;
  }

  List<VaultEntry> searchEntries(String query) {
    _requireUnlocked();
    if (query.isEmpty) return List.unmodifiable(_cache);

    final lowerQuery = query.toLowerCase();
    return _cache.where((e) {
      if (e.name.toLowerCase().contains(lowerQuery)) return true;
      if (e.notes?.toLowerCase().contains(lowerQuery) == true) return true;
      if (e.tags.any((t) => t.toLowerCase().contains(lowerQuery))) return true;
      for (final value in e.fields.values) {
        if (value.toLowerCase().contains(lowerQuery)) return true;
      }
      return false;
    }).toList();
  }

  List<VaultEntry> getEntriesByType(VaultEntryType type) {
    _requireUnlocked();
    return _cache.where((e) => e.type == type).toList();
  }

  List<VaultEntry> getFavorites() {
    _requireUnlocked();
    return _cache.where((e) => e.isFavorite).toList();
  }

  Future<VaultEntry> toggleFavorite(String entryId) async {
    _requireUnlocked();
    final entry = getEntry(entryId);
    if (entry == null) throw VaultException('Entry not found: $entryId');
    return updateEntry(entry.copyWith(isFavorite: !entry.isFavorite));
  }

  Future<void> recordAccess(String entryId) async {
    _requireUnlocked();
    final entry = getEntry(entryId);
    if (entry == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await updateEntry(entry.copyWith(accessedAt: now));
    await _audit.logView(entryId, entry.name);
  }

  String generatePassword({
    int length = 24,
    bool useUpper = true,
    bool useLower = true,
    bool useDigits = true,
    bool useSymbols = true,
    bool excludeAmbiguous = true,
  }) {
    return _passwordGenerator.generate(
      length: length,
      useUpper: useUpper,
      useLower: useLower,
      useDigits: useDigits,
      useSymbols: useSymbols,
      excludeAmbiguous: excludeAmbiguous,
    );
  }

  String estimatePasswordStrength(String password) {
    return _passwordGenerator.estimateStrength(password);
  }

  Future<String> exportBackup(String password) async {
    _requireUnlocked();
    return _backup.exportBackup(
      entries: _cache,
      password: password,
    );
  }

  Future<int> importBackup(String backupData, String password) async {
    final entries = await _backup.importBackup(
      backupData: backupData,
      password: password,
    );
    if (entries == null) {
      throw VaultException('Failed to import backup — wrong password or corrupt data');
    }
    _cache = entries;
    return entries.length;
  }

  Future<List<AuditEntry>> getAuditLog({int limit = 50}) async {
    return _audit.getLog(limit: limit);
  }

  Future<void> clearAuditLog() async {
    await _audit.clearLog();
  }

  Future<int> getEntryCount() async {
    return _cache.length;
  }

  int getEntryCountByType(VaultEntryType type) {
    return _cache.where((e) => e.type == type).length;
  }

  Future<void> updateConfig(VaultConfig config) async {
    _config = config;
  }

  Future<void> clearLocalCache() async {
    await _localStorage.clear();
  }

  Future<List<int>> signForChain(List<int> data) async {
    return _walletService.signChallenge(_identityId, data);
  }

  void _requireUnlocked() {
    if (!_isUnlocked) {
      throw VaultException('Vault is locked. Call unlock() first.');
    }
  }

  String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return crypto.sha256.convert(bytes).toString().substring(0, 32);
  }
}
