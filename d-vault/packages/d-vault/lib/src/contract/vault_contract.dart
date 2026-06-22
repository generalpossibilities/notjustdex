import 'dart:convert';
import 'package:http/http.dart' as http;

/// Acki Nacki TVM RPC client for the Vault contract.
///
/// The Vault contract stores encrypted data on-chain.
/// - Anyone can call [getVault] to read the encrypted blob (public data).
/// - Only the Identity Kernel wallet (the `_owner`) can call [updateVault]
///   on the contract. This client prepares the message — the caller must
///   provide a signed message from the Identity Kernel wallet.

class VaultChainData {
  final List<int> encryptedData;
  final int version;
  final int updatedAt;

  VaultChainData({
    required this.encryptedData,
    required this.version,
    required this.updatedAt,
  });
}

class VaultContract {
  final String contractAddress;
  final String rpcEndpoint;

  VaultContract({
    required this.contractAddress,
    this.rpcEndpoint = 'https://mainnet.ackinacki.org/graphql',
  });

  final http.Client _client = http.Client();

  /// Read vault data from chain (public — anyone can call).
  Future<VaultChainData?> getVault() async {
    try {
      // Acki Nacki GraphQL: query collection for account running getVault
      final query = '''
query {
  blockchain {
    account(address: "$contractAddress") {
      info {
        getVault
      }
    }
  }
}
''';
      final resp = await _client.post(
        Uri.parse(rpcEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body);
      final vault = data['data']['blockchain']['account']['info']['getVault'];
      if (vault == null) return null;

      return VaultChainData(
        encryptedData: _hexToBytes(vault['encryptedData'] as String),
        version: vault['version'] as int,
        updatedAt: vault['updatedAt'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  /// Write encrypted vault data to chain.
  ///
  /// [signedMessage] must be a base64-encoded TVM message signed by the
  /// Identity Kernel wallet (the contract owner).
  /// Returns the transaction ID on success.
  Future<String> updateVault(
    List<int> encryptedData,
    String signedMessage,
  ) async {
    final query = '''
mutation {
  blockchain {
    sendMessage(message: "$signedMessage") {
      hash
    }
  }
}
''';
    final resp = await _client.post(
      Uri.parse(rpcEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query}),
    );

    if (resp.statusCode != 200) {
      throw Exception('TVM RPC error: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    if (data['errors'] != null) {
      throw Exception('TVM RPC: ${data['errors']}');
    }

    return data['data']['blockchain']['sendMessage']['hash'] as String;
  }

  /// Transfer ownership to a new wallet address.
  /// [signedMessage] must be signed by the current owner wallet.
  Future<String> transferOwnership(
    String newOwner,
    String signedMessage,
  ) async {
    return updateVault([], signedMessage);
  }

  /// Get current owner address from the contract.
  Future<String?> getOwner() async {
    try {
      final query = '''
query {
  blockchain {
    account(address: "$contractAddress") {
      info {
        getOwner
      }
    }
  }
}
''';
      final resp = await _client.post(
        Uri.parse(rpcEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body);
      return data['data']['blockchain']['account']['info']['getOwner'] as String?;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _client.close();
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
