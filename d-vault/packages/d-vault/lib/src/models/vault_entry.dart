class EncryptedVault {
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> mac;

  EncryptedVault({required this.nonce, required this.ciphertext, required this.mac});
}

class PlaintextEntry {
  final String id;
  final String username;
  final String password;
  final String? url;
  final String? notes;
  final String category;
  final int createdAt;
  final int updatedAt;

  PlaintextEntry({
    required this.id,
    required this.username,
    required this.password,
    this.url,
    this.notes,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'password': password,
        'url': url,
        'notes': notes,
        'category': category,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory PlaintextEntry.fromJson(Map<String, dynamic> json) => PlaintextEntry(
        id: json['id'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
        url: json['url'] as String?,
        notes: json['notes'] as String?,
        category: json['category'] as String,
        createdAt: json['createdAt'] as int,
        updatedAt: json['updatedAt'] as int,
      );
}
