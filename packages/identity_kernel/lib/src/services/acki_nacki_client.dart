import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

/// Acki Nacki blockchain client via GraphQL API.
///
/// Acki Nacki uses Solidity smart contracts on a TVM (TON Virtual Machine).
/// The API is GraphQL at mainnet.ackinacki.org/graphql.
///
/// Address format: "workchain_id:64_hex_chars" (e.g. "0:653b9a6452c7...")
/// Balance: VMSHELL nanotokens (1 VMSHELL = 10^9 nanotokens)
class AckiNackiClient {
  final String graphqlUrl;
  final http.Client _http;

  static const String defaultEndpoint = 'https://mainnet.ackinacki.org/graphql';
  static const String testnetEndpoint = 'https://shellnet.ackinacki.org/graphql';
  static const int workchainId = 0;

  AckiNackiClient({String? graphqlUrl, http.Client? httpClient})
      : graphqlUrl = graphqlUrl ?? defaultEndpoint,
        _http = httpClient ?? http.Client();

  void dispose() => _http.close();

  /// Get account info by address (format: "0:64_hex_chars").
  Future<AnAccount> getAccount(String address) async {
    final query = '''
      query {
        blockchain {
          account(address: "$address") {
            info {
              address
              acc_type
              balance
              last_paid
              last_trans_lt
              code_hash
              data_hash
            }
          }
        }
      }
    ''';

    final result = await _graphQL(query);
    final data = result['data']['blockchain']['account'];
    if (data == null) {
      throw AnRpcException('Account not found: $address');
    }
    return AnAccount.fromJson(data['info'] as Map<String, dynamic>);
  }

  /// Check if a username is available on-chain.
  Future<bool> checkUsernameAvailability(String username) async {
    final addr = deriveAddressFromPublicKey(utf8.encode(username));
    try {
      await getAccount(addr);
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Resolve a username to its Acki Nacki address.
  Future<String> resolveUsername(String username) async {
    return deriveAddressFromPublicKey(utf8.encode(username));
  }

  /// Get VMSHELL balance in nanotokens for an address.
  Future<int> getBalance(String address) async {
    final account = await getAccount(address);
    return int.tryParse(account.balance) ?? 0;
  }

  /// Get all token balances for an address.
  Future<Map<String, int>> getBalances(String address) async {
    final vmshell = await getBalance(address);
    return {
      'VMSHELL': vmshell,
      'NACKL': 0, // NACKL is a staking token, queried differently
      'SHELL': 0, // SHELL is external computation credits
    };
  }

  /// Submit a transaction by building and sending an ABI-encoded message.
  Future<String> submitTransaction({
    required String functionName,
    required Map<String, dynamic> args,
    required List<int> privateKey,
  }) async {
    final pubKey = await _derivePublicKey(privateKey);

    final payload = jsonEncode({
      'function': functionName,
      'args': args,
    });

    final payloadBytes = utf8.encode(payload);
    final txHash = sha256.convert(payloadBytes).bytes;
    final signature = await _ed25519Sign(txHash, privateKey);

    final messageBoc = _buildBocEnvelope(payload, signature, pubKey);

    return _sendMessage(messageBoc);
  }

  /// Register identity on-chain.
  Future<String> registerIdentity({
    required String username,
    required List<int> publicKey,
    required List<int> privateKey,
    required List<int> identityRoot,
  }) async {
    return submitTransaction(
      functionName: 'registerIdentity',
      args: {
        'username': username,
        'pubkey': bytesToHex(publicKey),
        'identity_root': bytesToHex(identityRoot),
      },
      privateKey: privateKey,
    );
  }

  /// Rotate seed phrase on-chain.
  Future<bool> rotateSeedPhrase({
    required List<int> privateKey,
    required List<int> newIdentityRoot,
  }) async {
    final pubKey = await _derivePublicKey(privateKey);
    await submitTransaction(
      functionName: 'rotateSeed',
      args: {
        'pubkey': bytesToHex(pubKey),
        'identity_root': bytesToHex(newIdentityRoot),
      },
      privateKey: privateKey,
    );
    return true;
  }

  /// Follow a user (free intra-thread transaction).
  Future<bool> followUser({
    required List<int> privateKey,
    required String followeeAddress,
  }) async {
    final pubKey = await _derivePublicKey(privateKey);
    final address = deriveAddressFromPublicKey(pubKey);
    await submitTransaction(
      functionName: 'follow',
      args: {
        'follower': address,
        'followee': followeeAddress,
      },
      privateKey: privateKey,
    );
    return true;
  }

  /// Post content IPFS hash on-chain.
  Future<bool> postContentHash({
    required List<int> privateKey,
    required String contentHash,
  }) async {
    final pubKey = await _derivePublicKey(privateKey);
    await submitTransaction(
      functionName: 'postContent',
      args: {
        'pubkey': bytesToHex(pubKey),
        'content_hash': contentHash,
      },
      privateKey: privateKey,
    );
    return true;
  }

  /// Send a BOC message via GraphQL mutation.
  Future<String> _sendMessage(String messageBoc) async {
    final mutation = '''
      mutation {
        sendMessage(message: "$messageBoc") {
          hash
        }
      }
    ''';

    final result = await _graphQL(mutation);
    return result['data']['sendMessage']['hash'] as String;
  }

  /// Execute a GraphQL query/mutation.
  Future<Map<String, dynamic>> _graphQL(String query) async {
    final body = jsonEncode({'query': query});
    final response = await _http.post(
      Uri.parse(graphqlUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw AnRpcException('HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['errors'] != null) {
      final errors = decoded['errors'] as List;
      throw AnRpcException('GraphQL error: ${errors.first['message']}');
    }

    return decoded;
  }

  /// Build a BOC envelope (simplified for development).
  /// Production: use TVM SDK cell serialization.
  String _buildBocEnvelope(
    String payload,
    List<int> signature,
    List<int> publicKey,
  ) {
    final envelope = {
      'payload': payload,
      'signature': bytesToHex(signature),
      'public_key': bytesToHex(publicKey),
    };
    return base64.encode(utf8.encode(jsonEncode(envelope)));
  }

  static Future<List<int>> _ed25519Sign(List<int> message, List<int> privateKey) async {
    final ed25519 = Ed25519();
    final keyPair = SimpleKeyPair(
      SimpleKeyPairData(
        privateKey: privateKey,
        type: KeyPairType.ed25519,
      ),
    );
    final signature = await ed25519.sign(message, keyPair: keyPair);
    return signature.bytes.toList();
  }

  static List<int> _derivePublicKey(List<int> privateKey) async {
    final ed25519 = Ed25519();
    final keyPair = SimpleKeyPair(
      SimpleKeyPairData(
        privateKey: privateKey,
        type: KeyPairType.ed25519,
      ),
    );
    final pubKey = await keyPair.extractPublicKey();
    return pubKey.bytes;
  }
}

/// Acki Nacki account info.
class AnAccount {
  final String address;
  final String balance; // VMSHELL nanotokens (string due to size)
  final int accType; // 0=uninit, 1=active, 2=frozen, 3=nonExist
  final int lastPaid;
  final String lastTransLt;
  final String codeHash;
  final String dataHash;

  AnAccount({
    required this.address,
    required this.balance,
    required this.accType,
    required this.lastPaid,
    required this.lastTransLt,
    required this.codeHash,
    required this.dataHash,
  });

  factory AnAccount.fromJson(Map<String, dynamic> json) => AnAccount(
        address: json['address'] as String? ?? '',
        balance: json['balance'] as String? ?? '0',
        accType: json['acc_type'] as int? ?? 0,
        lastPaid: json['last_paid'] as int? ?? 0,
        lastTransLt: json['last_trans_lt'] as String? ?? '',
        codeHash: json['code_hash'] as String? ?? '',
        dataHash: json['data_hash'] as String? ?? '',
      );

  bool get isActive => accType == 1;
}

class AnRpcException implements Exception {
  final String message;
  AnRpcException(this.message);
  @override
  String toString() => 'AnRpcException: $message';
}

String bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> hexToBytes(String hex) {
  hex = hex.replaceFirst('0x', '');
  return List.generate(hex.length ~/ 2,
      (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
}

/// Derive an Acki Nacki address from a public key.
/// Format: "workchain_id:64_hex_chars"
String deriveAddressFromPublicKey(List<int> publicKey) {
  final hash = sha256.convert(publicKey).bytes;
  return '0:${bytesToHex(hash)}';
}

int parseVmshellBalance(String balance) {
  return int.tryParse(balance) ?? 0;
}

double vmshellToShell(int nanotokens) {
  return nanotokens / 1000000000;
}
