import 'permission.dart';

class MiniApp {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final String entryUrl;
  final String developer;
  final List<MiniAppPermission> requiredPermissions;
  final String version;
  final bool isInstalled;

  const MiniApp({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.entryUrl,
    required this.developer,
    this.requiredPermissions = const [],
    this.version = '1.0.0',
    this.isInstalled = false,
  });

  MiniApp copyWith({bool? isInstalled}) {
    return MiniApp(
      id: id,
      name: name,
      description: description,
      iconUrl: iconUrl,
      entryUrl: entryUrl,
      developer: developer,
      requiredPermissions: requiredPermissions,
      version: version,
      isInstalled: isInstalled ?? this.isInstalled,
    );
  }

  factory MiniApp.fromJson(Map<String, dynamic> json) {
    return MiniApp(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      iconUrl: json['icon_url'] as String,
      entryUrl: json['entry_url'] as String,
      developer: json['developer'] as String? ?? '',
      requiredPermissions: (json['required_permissions'] as List?)
              ?.map((e) => MiniAppPermission.values.firstWhere(
                    (p) => p.name == e,
                    orElse: () => MiniAppPermission.none,
                  ))
              .toList() ??
          [],
      version: json['version'] as String? ?? '1.0.0',
    );
  }
}
