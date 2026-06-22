import 'dart:math';
import 'models/vault_entry.dart';
import 'crypto/key_derivation.dart';
import 'crypto/vault_crypto.dart';
import 'contract/vault_contract.dart';

/// Main orchestrator for d-vault operations.
///
/// Does NOT handle authentication or recovery —
/// those come from the Identity Kernel.
///
/// Read flow:
///   1. [loadVault] loads encrypted data from chain via GraphQL (public read)
///   2. Decrypts with derived key
///
/// Write flow:
///   1. [encryptForSave] encrypts entries and returns serialized bytes
///   2. Caller (Identity Kernel) signs a message to the vault contract
///   3. [submitSignedUpdate] sends the signed message to chain
class DVaultService {
  final VaultContract _contract;
  final String _username;

  DVaultService({
    required VaultContract contract,
    required String username,
  })  : _contract = contract,
        _username = username;

  /// Load and decrypt the vault from chain.
  /// Returns null if vault is empty or decryption fails.
  Future<List<PlaintextEntry>?> loadVault({String? saltPassword}) async {
    final onChain = await _contract.getVault();
    if (onChain == null || onChain.encryptedData.isEmpty) {
      return [];
    }

    final key = await deriveVaultKey(
      username: _username,
      saltPassword: saltPassword,
    );

    final encrypted = deserializeVault(onChain.encryptedData);
    final entries = await decryptVault(encrypted, key.encryptionKey);
    return entries;
  }

  /// Encrypt entries and return serialized bytes ready for chain storage.
  /// Caller must have the Identity Kernel wallet sign and send these bytes
  /// to the vault contract's `update()` method.
  Future<List<int>> encryptForSave(
    List<PlaintextEntry> entries, {
    String? saltPassword,
  }) async {
    final key = await deriveVaultKey(
      username: _username,
      saltPassword: saltPassword,
    );

    final encrypted = await encryptVault(entries, key.encryptionKey);
    return serializeVault(encrypted);
  }

  /// Submit a pre-signed message to the vault contract on chain.
  /// The signed message must be produced by the Identity Kernel wallet
  /// (the contract owner) calling `vault.update(encryptedData)`.
  Future<String> submitSignedUpdate(String signedMessage) async {
    return _contract.updateVault([], signedMessage);
  }

  /// Full save: encrypt + submit signed message in one step.
  /// [signedMessage] must be the Identity Kernel wallet's signed message
  /// that includes the encrypted data as the payload.
  Future<String> saveVault(
    List<PlaintextEntry> entries, {
    String? saltPassword,
    required String signedMessage,
  }) async {
    final data = await encryptForSave(entries, saltPassword: saltPassword);
    return _contract.updateVault(data, signedMessage);
  }

  /// Decrypt raw data from chain. Useful if caller fetched data separately.
  Future<List<PlaintextEntry>?> decryptData(
    List<int> serializedData, {
    String? saltPassword,
  }) async {
    if (serializedData.isEmpty) return [];
    final key = await deriveVaultKey(
      username: _username,
      saltPassword: saltPassword,
    );
    final encrypted = deserializeVault(serializedData);
    return decryptVault(encrypted, key.encryptionKey);
  }

  /// Create a new entry.
  static PlaintextEntry newEntry({
    required String username,
    required String password,
    String? url,
    String? notes,
    String category = 'password',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _generateEntryId();
    return PlaintextEntry(
      id: id,
      username: username,
      password: password,
      url: url,
      notes: notes,
      category: category,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String _generateEntryId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
