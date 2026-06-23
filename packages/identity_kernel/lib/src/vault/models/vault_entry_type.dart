enum VaultEntryType {
  password,
  creditCard,
  totp,
  secureNote,
  identity,
  apiKey,
  bankAccount,
  custom;

  String get displayName {
    switch (this) {
      case VaultEntryType.password:
        return 'Password';
      case VaultEntryType.creditCard:
        return 'Credit Card';
      case VaultEntryType.totp:
        return 'TOTP';
      case VaultEntryType.secureNote:
        return 'Secure Note';
      case VaultEntryType.identity:
        return 'Identity';
      case VaultEntryType.apiKey:
        return 'API Key';
      case VaultEntryType.bankAccount:
        return 'Bank Account';
      case VaultEntryType.custom:
        return 'Custom';
    }
  }

  String get iconName {
    switch (this) {
      case VaultEntryType.password:
        return 'lock';
      case VaultEntryType.creditCard:
        return 'credit_card';
      case VaultEntryType.totp:
        return 'timer';
      case VaultEntryType.secureNote:
        return 'note';
      case VaultEntryType.identity:
        return 'badge';
      case VaultEntryType.apiKey:
        return 'vpn_key';
      case VaultEntryType.bankAccount:
        return 'account_balance';
      case VaultEntryType.custom:
        return 'extension';
    }
  }

  String get storageKey {
    switch (this) {
      case VaultEntryType.password:
        return 'password';
      case VaultEntryType.creditCard:
        return 'credit_card';
      case VaultEntryType.totp:
        return 'totp';
      case VaultEntryType.secureNote:
        return 'secure_note';
      case VaultEntryType.identity:
        return 'identity';
      case VaultEntryType.apiKey:
        return 'api_key';
      case VaultEntryType.bankAccount:
        return 'bank_account';
      case VaultEntryType.custom:
        return 'custom';
    }
  }

  static VaultEntryType fromStorageKey(String key) {
    return VaultEntryType.values.firstWhere(
      (e) => e.storageKey == key,
      orElse: () => VaultEntryType.custom,
    );
  }
}
