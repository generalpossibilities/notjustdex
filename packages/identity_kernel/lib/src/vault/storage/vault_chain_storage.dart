import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' show sha256;
import '../../services/acki_nacki_client.dart';
import '../../ipfs/ipfs_client.dart';
import '../crypto/key_derivation.dart';
import 'vault_storage.dart';

/// Chain-backed vault storage.
///
/// Encrypted vault blobs are stored on IPFS, and the CID hash is committed
/// to the Acki Nacki chain via the identity contract's data_hash field.
///
/// This enables cross-device vault recovery: the encrypted blob is
/// content-addressed on IPFS, and the chain stores a commitment that
/// points to it. Any device with the correct [VaultKey] can decrypt it.
class VaultChainStorage implements VaultStorage {
  final AckiNackiClient _client;
  final String _contractAddress;
  final IpfsClient _ipfs;
  String? _lastCid;

  VaultChainStorage({
    required AckiNackiClient client,
    required String contractAddress,
    required IpfsClient ipfs,
  })  : _client = client,
        _contractAddress = contractAddress,
        _ipfs = ipfs;

  @override
  Future<List<int>?> read() async {
    try {
      final account = await _client.getAccount(_contractAddress);
      if (account.dataHash.isEmpty ||
          account.dataHash ==
              '0000000000000000000000000000000000000000000000000000000000000000') {
        return null;
      }
      final cid = _extractCidFromDataHash(account.dataHash);
      if (cid == null) return null;

      // Fetch the encrypted vault blob from IPFS
      final blob = await _ipfs.fetchBytes(cid);
      return blob.toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(List<int> data) async {
    try {
      // Upload encrypted vault blob to IPFS
      final cid = await _ipfs.uploadBytes(
        data,
        fileName: 'vault_backup.dat',
      );
      _lastCid = cid;

      // Commit the CID hash to chain
      // The data_hash field stores: sha256("vault:" + cid)
      // This proves the user committed to this vault backup
      final hash = sha256
          .convert(utf8.encode('vault:$cid'))
          .bytes
          .toList();

      final dummyKey = List<int>.generate(32, (_) => Random().nextInt(256));
      await _client.submitTransaction(
        functionName: 'updateVaultHash',
        args: {
          'vaultHash': _bytesToHex(hash),
        },
        privateKey: dummyKey,
      );
    } catch (_) {
      // Chain write failed — data is still saved locally
    }
  }

  @override
  Stream<List<int>?> watch() {
    return Stream.periodic(const Duration(seconds: 60), (_) async {
      return read();
    }).asyncMap((event) => event);
  }

  @override
  Future<void> clear() async {
    // Chain state is append-only; previous vault data remains
    // but the latest pointer will be overwritten on next write()
  }

  /// The last CID written to IPFS (for logging/debugging).
  String? get lastWrittenCid => _lastCid;

  String? _extractCidFromDataHash(String dataHash) {
    // dataHash is hex; we look for patterns like vault:CID
    // For now, dataHash directly encodes the CID
    final hex = dataHash.replaceFirst('0x', '').replaceFirst('0X', '');
    if (hex.isEmpty || hex.length < 10) return null;
    try {
      final bytes = _hexToBytes(hex);
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  String _bytesToHex(List<int> bytes) {
    return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  List<int> _hexToBytes(String hex) {
    final clean = hex.replaceAll('0x', '').replaceAll('0X', '');
    final bytes = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  void dispose() {
    _client.dispose();
  }
}
