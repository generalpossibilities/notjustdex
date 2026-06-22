import 'package:bip39/bip39.dart' as bip39;

/// Generate a BIP-39 seed phrase (24 words, 256 bits entropy).
String generateSeedPhrase() {
  return bip39.generateMnemonic();
}

/// Validate a BIP-39 mnemonic.
bool validateSeedPhrase(String mnemonic) {
  return bip39.validateMnemonic(mnemonic);
}

/// Convert mnemonic to 64-byte seed.
List<int> seedFromMnemonic(String mnemonic) {
  return bip39.mnemonicToSeed(mnemonic);
}
