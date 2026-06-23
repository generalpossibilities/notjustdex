import 'dart:convert';
import 'vault_entry_type.dart';

class VaultEntry {
  final String id;
  final VaultEntryType type;
  final String name;
  final Map<String, String> fields;
  final String? notes;
  final List<String> tags;
  final bool isFavorite;
  final int createdAt;
  final int updatedAt;
  final int? accessedAt;
  final int version;

  const VaultEntry({
    required this.id,
    required this.type,
    required this.name,
    this.fields = const {},
    this.notes,
    this.tags = const [],
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.accessedAt,
    this.version = 1,
  });

  VaultEntry copyWith({
    String? id,
    VaultEntryType? type,
    String? name,
    Map<String, String>? fields,
    String? notes,
    List<String>? tags,
    bool? isFavorite,
    int? createdAt,
    int? updatedAt,
    int? accessedAt,
    int? version,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      fields: fields ?? this.fields,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      accessedAt: accessedAt ?? this.accessedAt,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.storageKey,
        'name': name,
        'fields': fields,
        if (notes != null) 'notes': notes,
        'tags': tags,
        'isFavorite': isFavorite,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        if (accessedAt != null) 'accessedAt': accessedAt,
        'version': version,
      };

  factory VaultEntry.fromJson(Map<String, dynamic> json) => VaultEntry(
        id: json['id'] as String,
        type: VaultEntryType.fromStorageKey(json['type'] as String),
        name: json['name'] as String,
        fields: (json['fields'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as String)) ??
            {},
        notes: json['notes'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        isFavorite: json['isFavorite'] as bool? ?? false,
        createdAt: json['createdAt'] as int,
        updatedAt: json['updatedAt'] as int,
        accessedAt: json['accessedAt'] as int?,
        version: json['version'] as int? ?? 1,
      );

  static String serializeList(List<VaultEntry> entries) {
    return jsonEncode(entries.map((e) => e.toJson()).toList());
  }

  static List<VaultEntry> deserializeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
