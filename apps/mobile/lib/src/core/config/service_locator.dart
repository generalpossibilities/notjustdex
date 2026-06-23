import 'features.dart';

/// Decentralized service locator.
///
/// Holds chain + IPFS services instead of Go HTTP clients.
/// In production: replace with get_it or riverpod.
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;
  ServiceLocator._();

  late AppConfig config;

  Future<void> init() async {
    config = await AppConfig.load();
  }
}
