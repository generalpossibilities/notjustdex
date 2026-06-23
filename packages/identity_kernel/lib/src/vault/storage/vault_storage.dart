abstract class VaultStorage {
  Future<List<int>?> read();
  Future<void> write(List<int> data);
  Stream<List<int>?> watch();
  Future<void> clear();
}
