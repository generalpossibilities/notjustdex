# d-vault → Identity Kernel Integration

## Overview

The Identity Kernel (IK) owns, deploys, and controls the d-vault Vault contract. d-vault itself is a **pure client-side package** that encrypts/decrypts data. The IK is the bridge to the chain.

## Flow

```
User opens d-vault in NotJustDex
  → IK verifies auth (phone/passkey/2FA)
  → IK loads Vault.sol contract (deploys if first time)
  → d-vault package decrypts & displays
  → User edits entries
  → d-vault package encrypts
  → IK signs & sends update to chain
```

## 3 Things the Identity Kernel Must Do

### 1. Deploy Vault Contract (once, on first open)

**When**: User opens d-vault for the first time.

**Contract**: `contracts/Vault.sol` (already compiled → `Vault.tvc` + `Vault.abi.json`)

```solidity
constructor(address owner, uint64 value)
```

- `owner` = IK wallet address (`msg.sender` at deploy time, i.e. the IK wallet contract address)
- `value` = 10 SHELL (10,000,000,000) to keep contract alive for gas

**TVM call** (from IK Go service):
```
tvm-cli deploy --abi Vault.abi.json --sign <ik-wallet-keys> Vault.tvc \
  '{"owner":"<IK_WALLET_ADDR>","value":10000000000}'
```

**Name registration** (optional but recommended):
```
tvm-cli call <domain-contract> register '{"name":"dvault","addr":"<VAULT_ADDR>"}'
```

**Result**: `Vault` contract deployed at address `VAULT_ADDR`. Store this in the user's IK profile.

---

### 2. Read Vault (every time d-vault opens)

**When**: Every time user navigates to d-vault.

**GraphQL query** (public read — any node):
```graphql
query {
  blockchain {
    account(address: "VAULT_ADDR") {
      info {
        getVault
      }
    }
  }
}
```

**Returns**:
```json
{
  "encryptedData": "hex...",   // TvmCell → bytes
  "version": 3,
  "updatedAt": 1718123456
}
```

**Pass to d-vault**: Feed `encryptedData` (raw bytes) to `DVaultService.decryptData()`.

```dart
final service = DVaultService(
  contract: VaultContract(contractAddress: vaultAddr),
  username: username,
);
final entries = await service.loadVault(saltPassword: userSalt);
```

---

### 3. Write Vault (every time user saves)

**When**: User edits entries and taps save.

**Client side** (d-vault Dart package):
```dart
final serializedBytes = await service.encryptForSave(entries, saltPassword: userSalt);
// → returns List<int> ready for chain
// Give this to the IK wallet to sign & send
```

**IK sign & send** (Go service):
```
1. Build TVC message: call vault.update(serializedBytes)
2. Sign with IK wallet key (ed25519)
3. Send to Acki Nacki via GraphQL mutation
```

**GraphQL mutation**:
```graphql
mutation {
  blockchain {
    sendMessage(message: "<base64-signed-tvm-message>") {
      hash
    }
  }
}
```

**Return**: Transaction hash. Store new `version` on the IK side for sync detection.

---

## Dart Package API (Reference)

```dart
// Initialize
final contract = VaultContract(
  contractAddress: "0:abcd...",
  rpcEndpoint: "https://mainnet.ackinacki.org/graphql",
);
final service = DVaultService(
  contract: contract,
  username: "@alice",  // from IK
);

// Read
final entries = await service.loadVault(saltPassword: null);
// ← null salt = key derived from @username only

// Encrypt (give bytes to IK for signing)
final data = await service.encryptForSave(entries, saltPassword: null);

// Decrypt raw bytes (if IK fetches data separately)
final entries2 = await service.decryptData(rawBytes, saltPassword: null);
```

## Files the IK team needs

| File | Copy to |
|---|---|
| `packages/d-vault/` | `notjustdex/packages/d-vault/` |
| `services/d-vault/` | `notjustdex/services/d-vault/` |
| `contracts/Vault.sol` | `notjustdex/contracts/vault/Vault.sol` |
| `contracts/Vault.abi.json` | `notjustdex/contracts/vault/Vault.abi.json` |

## What d-vault does NOT do

- ❌ Auth — handled by IK
- ❌ Wallet — IK has its own wallet contract
- ❌ Recovery — IK handles recovery
- ❌ Seed phrase for everyday access — IK handles login
- ❌ ZK proofs — IK handles uniqueness (TBD implementation)
