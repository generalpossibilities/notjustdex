# NotJustDex

Decentralized social platform built on **Acki Nacki**

## Architecture

**First-principles decentralization.** Every Go service is optional. The authoritative source of truth is the Acki Nacki chain + IPFS. All modules degrade gracefully when offline.

| Layer | Tech |
|-------|------|
| Identity | On-chain (Acki Nacki immutable username + Ed25519 passkey) |
| Storage | IPFS (content-addressed) + Hive (local cache) |
| Chat | P2P over relays + MLS (TreeKEM, HPKE, X25519, Ed25519, AES-256-GCM) |
| Auth | Passkey (WebAuthn), Phone OTP, Wallet ZKP — no passwords |

## Quick Start

```bash
make bootstrap    # dart pub global activate melos && melos bootstrap
make gen          # regenerate protos + freezed + json_serializable
make analyze      # dart analyze across all packages
make test         # run all Dart tests
```

## Monorepo Structure

```
apps/
  mobile/           Flutter mobile app (Material 3 dark, Impeller)
  web/              Flutter web app
packages/
  identity_kernel/    Core identity + wallet (must build first)
  decentralized_chat/ MLS-encrypted P2P messaging
  decentralized_storage/ IPFS/Filecoin/Arweave multi-backend
  mini_app_runtime/   Sandboxed WebView mini app platform
  design_system/      Dark-first Flutter component library
  mls_encryption/     Messaging Layer Security primitives
  passkey_service/    Cross-platform WebAuthn
  in_app_browser/     WebView with deep link handling
  shared_proto/       Protobuf definitions
  vault/              Decentralized password manager (in identity_kernel)
services/
  chat_relay/         Dart WebSocket pub/sub (anyone can self-host)
  notjustdex-...      Go services (optional relay/indexers)
```

## Key Design Decisions

- **Wallet is invisible** — auto-created from passkey, no blockchain terms during signup
- **Progressive onboarding** — phone verify → home immediately, identity setup from settings
- **Username = wallet name** on Acki Nacki chain, immutable after registration
- **Display name** is a separate, changeable social handle (min 4 chars)
- **Every module is pluggable** — remove any without breaking the app
- **No passwords** — passkey + ZKP replaces them entirely




