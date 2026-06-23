import 'dart:convert';
import '../../services/acki_nacki_client.dart';
import 'vault_storage.dart';

class VaultChainStorage implements VaultStorage {
  final AckiNackiClient _client;
  final String _contractAddress;

  VaultChainStorage({
    required AckiNackiClient client,
    required String contractAddress,
  })  : _client = client,
        _contractAddress = contractAddress;

  @override
  Future<List<int>?> read() async {
    try {
      final account = await _client.getAccount(_contractAddress);
      if (account.dataHash.isEmpty || account.dataHash == '0000000000000000000000000000000000000000000000000000000000000000') {
        return null;
      }
      final dataHash = account.dataHash;
      final hex = dataHash.replaceFirst('0x', '').replaceFirst('0X', '');
      if (hex.isEmpty || hex == '0' * 64) return null;
      return _hexToBytes(hex);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(List<int> data) async {
    throw UnsupportedError(
      'VaultChainStorage requires signing context. Use VaultService.saveVault() instead.',
    );
  }

  @override
  Stream<List<int>?> watch() {
    return Stream.periodic(const Duration(seconds: 60), (_) async {
      return read();
    }).asyncMap((event) => event);
  }

  @override
  Future<void> clear() async {
    throw UnsupportedError(
      'VaultChainStorage.clear() is not supported. Use the contract directly.',
    );
  }

  void dispose() {
    _client.dispose();
  }

  List<int> _hexToBytes(String hex) {
    final clean = hex.replaceAll('0x', '').replaceAll('0X', '');
    final bytes = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
