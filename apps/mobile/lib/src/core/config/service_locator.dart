import 'package:notjustdex_identity_kernel/identity_kernel.dart';
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
  AnLightClient? _lightClient;
  AnIdentityContract? _identityContract;

  AnLightClient get lightClient {
    if (_lightClient == null) throw StateError('ServiceLocator not initialized');
    return _lightClient!;
  }

  AnIdentityContract get identityContract {
    if (_identityContract == null) throw StateError('ServiceLocator not initialized');
    return _identityContract!;
  }

  Future<void> init() async {
    config = AppConfig.fromDefine();

    // Initialize chain client with fallback RPC endpoints
    _lightClient = AnLightClient([
      'https://mainnet.ackinacki.org/graphql',
      'https://shellnet.ackinacki.org/graphql',
    ]);

    _identityContract = AnIdentityContract(
      client: _lightClient!,
      contractAddress: '0:notjustdex_identity_contract', // placeholder
    );
  }
}
