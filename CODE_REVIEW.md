# Code Review — NotJustDex

Date: 2026-06-22 (updated 2026-06-23)
Evaluated: ~25K LOC across 195+ source files (Dart, Go, Proto, YAML)

---

## Scoring Summary (Updated)

| Category | Score | Notes |
|----------|-------|-------|
| Architecture | 9/10 | Decentralized auth eliminates Go relay dependency |
| Flutter App | 7/10 | DI via ServiceLocator, Hive persistence, config injection |
| Go Services | 5/10 | Auth functional but now legacy — being replaced by on-chain auth |
| Packages | 8/10 | Identity kernel rewritten for full on-chain auth; MLS crypto fixed |
| Config/Infra | 8/10 | .env.example created, Makefile fixed, Hive wired |
| Security | 7/10 | All crypto placeholders replaced with real Ed25519/X25519/AES-256-GCM |
| Tests | 1/10 | Still no tests — CI gap remains |
| **Overall** | **6.4/10** | **Critical crypto + auth issues resolved; decentralization is architectural** |

---

## Architecture (9/10)

### Strengths
- Monorepo with clean separation: `apps/`, `packages/`, `services/`, `lib/go/`
- `AppModule` abstract class + `ModuleRouter` — well-designed pluggable module system
- Every Go service follows consistent structure: `cmd/server/main.go` -> `internal/{handler,service,models,repository}`
- Feature flags in `config/features.yaml` drive runtime availability
- Every Go service exposes `/health/live` + `/health/ready`
- **DECENTRALIZATION.md** rewritten — zero Go services required; app works directly with Acki Nacki chain
- **New auth architecture**: passkey-first, phone as optional bootstrap, on-chain identity registration (no Go relay)

### Issues (Remaining)
- `lib/go/` is now dead code (was Go relay library) — should be deleted once migration complete
- SQL migrations exist but nothing connects to PostgreSQL (irrelevant post-decentralization — chain is storage)
- Go services still built in Docker Compose but shouldn't be

---

## Flutter App (7/10)

### Strengths
- Well-structured onboarding flow (welcome -> phone -> verify -> username)
- Tour page with TikTok-style vertical swipe
- Feed page with double-tap heart animation, mini app cards, comment bottom sheet
- Phone country code picker with search/filter
- **ServiceLocator** created for DI (`src/core/config/service_locator.dart`)
- **SessionService** now persists to Hive (was in-memory)
- **FeedApiClient** injected via constructor, not hardcoded
- **Features/AppConfig** loads from `--dart-define` + YAML with platform-aware defaults

### Issues (Remaining)
- `auth_page.dart` doesn't match the unified Register/Log In/Wallet tab design from AGENTS.md — needs refactor for passkey-first flow
- No error handling for chain-down scenarios (AN RPC unavailable)
- `FeedApiClient` uses raw `dart:io` `HttpClient` — no interceptors, auth headers, or read timeouts
- `features.dart:92` loads from `config/features.yaml` relative to CWD — needs asset bundle path for production

---

## Go Services (5/10 — UNCHANGED)

### Strengths
- Auth service: all phone/passkey/wallet ZKP endpoints wired
- Feed service: proper scoring algorithm with time decay + engagement weights
- Chat service: WebSocket hub with broadcast pattern
- Consistent health endpoints across all 11 services

### Issues (All FIXED)
| Issue | Fix |
|-------|-----|
| `chat/ws/hub.go:15` — `CheckOrigin` returns `true` | Uses allowlist now |
| `auth/main.go:15` — hardcoded dev JWT secret | Required env var `JWT_SECRET`, fatal if empty |
| `auth/handler.go:64` — unsafe error JSON encoding | Uses `writeJSONError()` helper |
| `feed/service/service.go:33` — AuthorID panic | Length check before `[:8]` |
| `registry/registry.go:88` — deadlock | Copy client map under RLock |

### Status
All Go services still **pass `go build` + `go vet`**. However, they are now **legacy** — the app's auth/identity is fully on-chain, making these services unnecessary. Phase 4 of the decentralization plan will delete them.

---

## Packages (8/10)

### Identity Kernel (FIXED)

| Issue | Fix |
|-------|-----|
| `WalletService` casts to `MpcWalletRepository` | Added `getPublicKey/getPrivateKey` to interface |
| `AckiNackiClient._ed25519Sign` used HMAC-SHA256 | Now uses `SimpleKeyPair(SimpleKeyPairData(...))` with real Ed25519 |
| `AuthenticationService` entirely stub-based | Replaced with `DecentralizedAuthService` — passkey + wallet + on-chain |
| Wallet keys from nowhere | Derived from passkey credential ID via SHA256 |
| No on-chain identity registration | `AnIdentityContract` + `AnLightClient` — direct RPC to AN chain |
| Session = stubs | Session = signed challenge, verified against on-chain public key |
| `Profile` model missing username | Added `username`, `avatarCid`, `coverCid`, `joinedAt` |
| `UserIdentity` missing publicKey field | Added `publicKey`, `identityCid` |

### MLS Encryption (FIXED)
| Issue | Fix |
|-------|-----|
| SHA-256 instead of X25519 keygen | Uses `cryptography` package `X25519()` |
| HMAC-SHA256 instead of Ed25519 signing | Uses `Ed25519().sign()` with `SimpleKeyPair` |
| HMAC-SHA256 instead of Ed25519 verify | Uses `Ed25519().verify()` with `Signature` |
| SHA-256 instead of AES-256-GCM | Uses `cryptography` package `AES-256-GCM` |

### Passkey Service (FIXED)
| Issue | Fix |
|-------|-----|
| Challenge uses `DateTime.now() % 256` | Uses `Random.secure()` for 32-byte challenge |

### Mini App Runtime & In-App Browser
- Well-structured JS bridge with handler pattern ✅
- Deep link handler is clean ✅

---

## Security (7/10)

| Severity | File | Issue | Status |
|----------|------|-------|--------|
| **Critical** | `passkey_service.dart:237` | Challenge predictable | **FIXED** — uses `Random.secure()` |
| **Critical** | `acki_nacki_client.dart:234` | HMAC instead of Ed25519 | **FIXED** — real Ed25519 via `cryptography` |
| **Critical** | `mls_crypto.dart:18-26` | SHA-256 instead of X25519 | **FIXED** — real X25519 |
| **Critical** | `mls_crypto.dart:111` | HMAC instead of Ed25519 | **FIXED** — real Ed25519 |
| **High** | `chat/ws/hub.go:15` | WebSocket allows all origins | **FIXED** — allowlist |
| **High** | `auth/main.go:15` | Dev JWT secret hardcoded | **FIXED** — env var required |
| **Medium** | `auth/handler.go:64` | Unsafe JSON encoding | **FIXED** — `writeJSONError()` helper |
| **Medium** | `wallet_service.dart:114-128` | Tight cast exposes keys | **FIXED** — interface methods |
| **Low** | `wallet_repository.dart:188-198` | In-memory only | **ACCEPTED** — local dev; production uses secure enclave |
| **Low** | `SessionService` | No persistent encryption | **MITIGATED** — Hive stores locally; seed phrases will use flutter_secure_storage |

---

## Configuration & Infrastructure (8/10)

### FIXED
| Issue | Fix |
|-------|-----|
| Makefile inconsistent indentation | Fixed tab on line 8 |
| No `.env.example` | Created with all service config keys |
| `10.0.2.2:8083` hardcoded | `FeedApiClient` injected via constructor; `AppConfig` has platform-aware defaults |
| No `notificationsHost` in config | Already present in `AppConfig` + `FeatureFlags` |
| Chat/Notifications modules hardcoded hosts | Accept `AppConfig` via constructor |

### Remaining
- DAO service `enabled: false` but still built in Docker Compose
- No healthcheck or restart policy on Docker services
- `lib/go/` should be deleted (no longer used)

---

## Tests (1/10) — UNCHANGED

| Language | Test Files | Status |
|----------|-----------|--------|
| Dart | 3 (`identity_service_test.dart`, `username_test.dart`, `d_vault_test.dart`) | Minimal coverage |
| Go | 0 | **No tests anywhere** |

This is the biggest remaining gap. The decentralized auth service has zero tests.

---

## What Was Fixed (Complete List)

### Cryptographic (Critical)
1. `mls_crypto.dart` — X25519 keygen, Ed25519 signing, AES-256-GCM encryption via `cryptography` package
2. `acki_nacki_client.dart` — `_ed25519Sign` now uses real Ed25519 via `SimpleKeyPair` + `SimpleKeyPairData`
3. `wallet_repository.dart` — `_ed25519Sign` and `_ed25519Verify` now use real Ed25519
4. `passkey_service.dart` — challenge uses `Random.secure()` not `DateTime.now() % 256`

### Go Services
5. `chat/ws/hub.go` — `CheckOrigin` uses allowlist
6. `auth/main.go` — `JWT_SECRET` env var required; fatal if empty
7. `auth/handler.go` — all errors use `writeJSONError()` helper
8. `feed/service/service.go` — AuthorID length guard
9. `registry/registry.go` — deadlock fix

### Flutter
10. `SessionService` — persisted to Hive (was in-memory)
11. `ServiceLocator` — new class holds `AppConfig`, `AuthClient`, `UsersClient`
12. `FeedModule`, `ChatModule`, `NotificationsModule` — accept `AppConfig` via constructor
13. `FeedApiClient.view()` — uses proper `_post()` call
14. `main.dart` — `Hive.initFlutter()` + `ServiceLocator.init()`

### Identity Kernel (Decentralization)
15. `DecentralizedAuthService` — new: passkey-first, wallet ZKP, phone bootstrap
16. `AnLightClient` — new: direct AN RPC, fallback endpoints
17. `AnIdentityContract` — new: on-chain identity ops
18. `IdentityService` — rewritten: direct chain interaction
19. `WalletService` — rewritten: keys derived from passkey credential ID
20. `AuthenticationService` — rewritten: delegates to `DecentralizedAuthService`
21. `IdentityBloc` — rewritten: new events for passkey/wallet auth
22. `Profile` model — added username, avatarCid, joinedAt
23. `Wallet` model — added publicKeyBytes, privateKeyBytes
24. `UserIdentity` model — added publicKey, identityCid
25. `IdentityRepository` interface — added `saveIdentity`
26. `WalletRepository` interface — added `getPublicKey`, `getPrivateKey`

### Infra
27. `Makefile` — fixed indentation
28. `.env.example` — created
29. `DECENTRALIZATION.md` — fully rewritten with new architecture

---

## Top 3 Remaining Priorities

1. **Write tests** — `DecentralizedAuthService`, `AnIdentityContract`, and `WalletService` have zero tests. Starting with these is critical since they handle auth and key material.

2. **Phase 2: IPFS + chain feed** — IPFS content upload from Flutter, chain event listener for feed, local scoring engine. This eliminates the feed and media Go services.

3. **Phase 3: Waku P2P chat** — Replace Go chat WebSocket with Waku relay. This is the last remaining centralized dependency.

4. **(Phase 4 cleanup)** — Delete all `services/*/` and `lib/go/` directories. Update Docker Compose and CI.
