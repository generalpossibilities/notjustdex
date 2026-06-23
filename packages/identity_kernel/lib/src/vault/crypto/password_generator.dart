import 'dart:math';

const String _lower = 'abcdefghijklmnopqrstuvwxyz';
const String _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const String _digits = '0123456789';
const String _symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?~';
const String _ambiguous = 'il1Lo0O';

class PasswordGenerator {
  final Random _random = Random.secure();

  String generate({
    int length = 24,
    bool useUpper = true,
    bool useLower = true,
    bool useDigits = true,
    bool useSymbols = true,
    bool excludeAmbiguous = true,
  }) {
    if (length < 4) {
      throw ArgumentError('Password length must be at least 4');
    }

    String chars = '';
    if (useLower) chars += _lower;
    if (useUpper) chars += _upper;
    if (useDigits) chars += _digits;
    if (useSymbols) chars += _symbols;

    if (chars.isEmpty) {
      throw ArgumentError('At least one character set must be selected');
    }

    if (excludeAmbiguous) {
      chars = chars.split('').where((c) => !_ambiguous.contains(c)).join();
    }

    if (chars.isEmpty) {
      chars = _lower + _upper + _digits;
    }

    final password = List.generate(length, (_) {
      return chars[_random.nextInt(chars.length)];
    }).join();

    return _ensureRequirements(
      password: password,
      length: length,
      useUpper: useUpper,
      useLower: useLower,
      useDigits: useDigits,
      useSymbols: useSymbols,
      chars: chars,
    );
  }

  String _ensureRequirements({
    required String password,
    required int length,
    required bool useUpper,
    required bool useLower,
    required bool useDigits,
    required bool useSymbols,
    required String chars,
  }) {
    final result = password.split('').toList();

    void ensureChar(bool required, String source, int index) {
      if (!required) return;
      if (!source.contains(result[index])) {
        result[index] = source[_random.nextInt(source.length)];
      }
    }

    for (var i = 0; i < length; i++) {
      ensureChar(useUpper, _upper, i);
      ensureChar(useLower, _lower, i);
      ensureChar(useDigits, _digits, i);
      ensureChar(useSymbols, _symbols, i);
    }

    result.shuffle(_random);
    return result.join();
  }

  String estimateStrength(String password) {
    var entropy = 0.0;
    if (password.contains(RegExp(r'[a-z]'))) entropy += 26;
    if (password.contains(RegExp(r'[A-Z]'))) entropy += 26;
    if (password.contains(RegExp(r'[0-9]'))) entropy += 10;
    if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) entropy += 33;

    final bits = password.length * (entropy > 0 ? (entropy / _log2(entropy)) : 0);

    if (bits < 28) return 'Weak';
    if (bits < 56) return 'Fair';
    if (bits < 80) return 'Good';
    if (bits < 128) return 'Strong';
    return 'Very Strong';
  }

  double _log2(double x) => x > 0 ? _ln(x) / 0.6931471805599453 : 1;
  double _ln(double x) {
    final est = x.toStringAsFixed(0).length;
    return est > 0 ? est * 2.302585 / 0.693147 : 1;
  }
}
