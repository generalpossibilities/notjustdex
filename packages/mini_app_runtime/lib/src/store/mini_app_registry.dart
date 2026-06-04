import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/mini_app.dart';
import '../models/permission.dart';

class MiniAppRegistry extends ChangeNotifier {
  final List<MiniApp> _installed = [];

  List<MiniApp> get installed => List.unmodifiable(_installed);

  static final List<MiniApp> _available = [
    MiniApp(
      id: 'wallet',
      name: 'Wallet',
      description: 'View balance, send & receive tokens, explore Acki Nacki',
      iconUrl: 'https://dexchats.io/miniapps/wallet/icon.png',
      entryUrl: 'https://dexchats.io/miniapps/wallet/',
      developer: 'DexChats',
      requiredPermissions: [MiniAppPermission.identity, MiniAppPermission.wallet, MiniAppPermission.payments],
    ),
    MiniApp(
      id: 'dao',
      name: 'DAO',
      description: 'Vote on proposals, stake tokens, govern the platform',
      iconUrl: 'https://dexchats.io/miniapps/dao/icon.png',
      entryUrl: 'https://dexchats.io/miniapps/dao/',
      developer: 'DexChats',
      requiredPermissions: [MiniAppPermission.identity, MiniAppPermission.wallet],
    ),
    MiniApp(
      id: 'creator',
      name: 'Creator Studio',
      description: 'Analytics, monetization, content management',
      iconUrl: 'https://dexchats.io/miniapps/creator/icon.png',
      entryUrl: 'https://dexchats.io/miniapps/creator/',
      developer: 'DexChats',
      requiredPermissions: [MiniAppPermission.identity, MiniAppPermission.notifications],
    ),
    MiniApp(
      id: 'market',
      name: 'Marketplace',
      description: 'Buy, sell, trade digital goods and NFTs',
      iconUrl: 'https://dexchats.io/miniapps/market/icon.png',
      entryUrl: 'https://dexchats.io/miniapps/market/',
      developer: 'DexChats',
      requiredPermissions: [MiniAppPermission.identity, MiniAppPermission.wallet, MiniAppPermission.payments],
    ),
    MiniApp(
      id: 'games',
      name: 'Games Hub',
      description: 'Play casual games, earn rewards',
      iconUrl: 'https://dexchats.io/miniapps/games/icon.png',
      entryUrl: 'https://dexchats.io/miniapps/games/',
      developer: 'DexChats',
      requiredPermissions: [MiniAppPermission.identity],
    ),
  ];

  List<MiniApp> get available {
    final installedIds = _installed.map((e) => e.id).toSet();
    return _available.where((a) => !installedIds.contains(a.id)).toList();
  }

  void install(MiniApp app) {
    if (_installed.any((e) => e.id == app.id)) return;
    _installed.add(app.copyWith(isInstalled: true));
    notifyListeners();
  }

  void uninstall(String appId) {
    _installed.removeWhere((e) => e.id == appId);
    notifyListeners();
  }

  bool isInstalled(String appId) {
    return _installed.any((e) => e.id == appId);
  }

  MiniApp? getById(String appId) {
    return _installed.where((e) => e.id == appId).firstOrNull;
  }

  String serialize() {
    final ids = _installed.map((e) => e.id).toList();
    return jsonEncode(ids);
  }

  void deserialize(String data) {
    final ids = jsonDecode(data) as List;
    for (final id in ids) {
      final app = _available.where((a) => a.id == id).firstOrNull;
      if (app != null) {
        _installed.add(app.copyWith(isInstalled: true));
      }
    }
    notifyListeners();
  }
}
