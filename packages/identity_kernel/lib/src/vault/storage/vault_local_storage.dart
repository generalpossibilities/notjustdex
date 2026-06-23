import 'package:hive/hive.dart';
import 'vault_storage.dart';

const String _boxName = 'vault_cache';

class VaultLocalStorage implements VaultStorage {
  late final Box<List<int>> _box;
  bool _initialized = false;

  Future<void> init() async {
    if (!_initialized) {
      _box = await Hive.openBox<List<int>>(_boxName);
      _initialized = true;
    }
  }

  @override
  Future<List<int>?> read() async {
    if (!_initialized) await init();
    return _box.get('encrypted_vault');
  }

  @override
  Future<void> write(List<int> data) async {
    if (!_initialized) await init();
    await _box.put('encrypted_vault', data);
  }

  @override
  Stream<List<int>?> watch() {
    if (!_initialized) {
      return Stream.value(null);
    }
    return _box.watch(key: 'encrypted_vault').map((event) => event.value);
  }

  @override
  Future<void> clear() async {
    if (!_initialized) await init();
    await _box.delete('encrypted_vault');
  }

  Future<void> close() async {
    if (_initialized) {
      await _box.close();
      _initialized = false;
    }
  }

  Future<void> deleteAll() async {
    if (!_initialized) await init();
    await _box.clear();
  }
}
