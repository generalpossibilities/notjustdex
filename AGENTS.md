# AGENTS.md — NotJustDex

## What this repo is

Monorepo for NotJustDex (social media platform: Telegram-grade messaging, TikTok-grade feeds, Web3 ownership on Acki Nacki).

## Critical Rules

### Decentralization-first
- **Go services are OPTIONAL relay/indexers.** The authoritative source of truth is Acki Nacki chain + IPFS. See `DECENTRALIZATION.md`.
- Every Go service must degrade gracefully when offline. No feature should hard-require a Go service forever.
- Anyone must be able to self-host any Go service.

### Identity is on-chain
- Username = immutable Acki Nacki wallet address name (checked on-chain at registration). Cannot be changed.
- Display name = changeable social handle (min 4 chars, separate from username).
- Wallet is auto-created silently when username is accepted. No "wallet" or "blockchain" visible during signup.

### Authentication
- **Phone** (primary, first-time): E.164 international format with country code selector.
- **Passkey** (WebAuthn, returning): biometric login, recommended method.
- **Wallet ZKP** (advanced): zero-knowledge proof challenge signed by MPC wallet.
- Unified auth page: one screen with Register / Log In / Wallet tabs. No separate flows.
- JWT tokens expire in 7 days. Cached locally for 24h offline use.

### Pre-registration Tour
- `/tour` route: TikTok-style feed preview before signup.
- Floating "Log In / Sign Up" buttons in top bar.
- After signup, redirect to `/home` with full modules.

### Profile
- Display name: changeable in Settings, min 4 chars, separate from immutable username.
- Profile photo: settable in Settings (tapped to change).
- Seed phrase export: password-gated in Settings → Security (24 words).
- Seed phrase rotation: supported (unique Acki Nacki feature).

### Phone Input (International)
- Country code dropdown with flag emoji + code (200+ countries).
- Search/filter by country name or code.
- E.164 output format.
- Uses `libphonenumber` for validation (when available).

### Architecture: Every module is connectable/disconnectable
- ALL Go services are optional — app must work without any of them.
- Local state (Isar/Hive) for offline cache.
- Feature flags in `config/features.yaml`.

## Identity Kernel (build first)

Architecture per `info.md` — wallet is **part of identity**, not a separate module. Every module consumes the Identity Kernel.

The kernel is a Dart package (`notjustdex_identity_kernel`) with:
- `lib/src/models/` — freezed models (UserIdentity, Wallet, Profile, Username, AuthenticationMethod)
- `lib/src/services/` — IdentityService, AuthenticationService, WalletService, RecoveryService
- `lib/src/repositories/` — abstract repos (IdentityRepository, WalletRepository)
- `lib/src/bloc/` — IdentityBloc (flutter_bloc)
- Generated files `*.freezed.dart`, `*.g.dart` require `melos run gen` after edits

## Monorepo structure

| Path | What |
|------|------|
| `apps/mobile/` | Flutter mobile app (Impeller, Material 3 dark) |
| `apps/web/` | Flutter web app |
| `packages/identity_kernel/` | Core identity+wallet package |
| `packages/design_system/` | Flutter design system (dark-first, skeleton loaders) |
| `packages/shared_proto/` | Protobuf definitions + buf config |
| `packages/in_app_browser/` | Flutter in-app browser (WebView, nav controls, deep links) |
| `packages/mini_app_runtime/` | Mini app runtime (sandboxed WebView + JS bridge + registry + store) |
| `packages/passkey_service/` | Cross-platform WebAuthn (passkey) — Android CredentialManager, iOS ASAuthorizationController, web navigator.credentials |
| `packages/mls_encryption/` | MLS (Messaging Layer Security) E2E encryption — TreeKEM, HPKE, X25519, Ed25519, AES-256-GCM |
| `packages/decentralized_chat/` | P2P chat over relays + MLS encryption — multi-relay client, Hive persistence, DecentralizedChatService |
| `packages/decentralized_storage/` | Decentralized content storage — IPFS + Filecoin + Arweave + Storj, HLS video processing, multi-backend replication with redundancy guarantees |
| `services/chat_relay/` | Dart chat relay server (shelf_web_socket) — anyone can run one, topic-based pub/sub |
| `infrastructure/` | Docker, K8s, Terraform stubs |

## In-App Browser & Mini Apps

`packages/in_app_browser/` — WebView wrapper with:
- Navigation bar (back, forward, refresh, share, URL bar)
- Deep link handler: intercepts `notjustdex://miniapp/{id}`, `notjustdex://profile/{username}`, etc.
- Progress indicator, external browser fallback

`packages/mini_app_runtime/` — Sandboxed mini app platform:
- `MiniApp` model (id, name, icon, entry URL, permissions)
- `MiniAppRegistry` — install/uninstall/persist
- `NotJustDexJsBridge` — JS bridge injected into every mini app WebView, exposing:
  - `notjustdex.getIdentity(cb)` → username, displayName, avatar
  - `notjustdex.getWallet(cb)` → address, balance (no private keys)
  - `notjustdex.requestPayment(to, amount, cb)` → MPC-signed tx
  - `notjustdex.showToast(message)`, `notjustdex.shareContent(data)`
- Permission request dialog per app (identity, wallet, payments, camera, mic, location, notifications)
- `MiniAppStorePage` — storefront to browse/install mini apps

Built-in mini apps: Wallet, DAO, Creator Studio, Marketplace, Games Hub.

Deep links handled via `DeepLinkHandler` (parses `notjustdex://*` URIs inside the browser and routes to native pages).

## Unified Feed (TikTok-style)

- `FeedItem` model: type (video, image, text, story), media URLs, engagement metrics, score, IPFS CIDs
- Scoring algorithm: time decay + engagement weight (likes×1, comments×2, shares×3, views×0.1) × content type boost (video×1.3, story×1.2, image×1.1)
- Chain event listener for `PostContent` events + IPFS content fetch by CID
- Local scoring engine (same formula as original Go feed, now client-side)
- Flutter `FeedApiClient` connects to decentralized feed service

Flutter `apps/mobile/lib/src/feed/` — vertical swipe feed:
- `PageView.builder` with vertical scroll direction (TikTok-inspired)
- Card types: video, image, text, story, **miniApp** — distinct color per type
- **MiniAppCard** — feed-embedded mini app cards (Farcaster Frames pattern); tap opens the mini app
- Right-side action bar: like (heart animation), comment, share, save
- **Double-tap to like** with heart overlay animation
- Comment sheet (bottom sheet with input), count formatting (1.2K, 3.4M)
- API-driven with fallback to mock data

## Architecture: Connectable/Disconnectable Modules

**Every module is independently pluggable.** No module hard-depends on another. A module can be
removed (feature flag, backend down, or excluded at build time) without breaking the app.

### Module types

| Type | If Disconnected |
|------|-----------------|
| `Required` | App shows error screen + retry |
| `Optional` | Tab/feature hidden; app still usable |
| `Enhanced` | Feature silently disabled |

### Dependency graph

```
Required ─── identity_kernel (chain + IPFS)
Optional ─── chat, feed, notifications, mini_app_runtime
Enhanced ─── creator_economy, search, analytics, dao
```

No Go services. All modules are chain-native or local-only.

### Flutter: AppModule system

Every UI feature is an `AppModule` in `lib/src/core/modules/`:

```dart
abstract class AppModule {
  String get name;
  bool get isAvailable;         // flag + connectivity
  Widget? get tabWidget;        // null = no tab in nav
  NavigationDestination? get tabDestination;  // null = no tab
  List<GoRoute> get routes;     // contributed to app router
  Future<void> onConnect();     // called when backend available
  void onDisconnect();          // called when connection lost
}
```

The `ModuleRouter` builds the complete route tree + bottom nav from registered modules.
`config/features.yaml` drives which modules are enabled at startup.

### Adding a new module

1. Create `lib/src/core/modules/<name>_module.dart` extending `AppModule`
2. Add to `_createModules()` in `main.dart`
3. Add flag to `config/features.yaml`

## Navigation (dynamic bottom nav)

The bottom nav is built from registered modules at runtime. The number of tabs depends
on which modules are available:

| Tab | Module | Type | Disconnected Behavior |
|-----|--------|------|----------------------|
| Feed | FeedModule | Optional | Tab hidden; toast "Feed unavailable" |
| Chat | ChatModule | Optional | Tab hidden; messages queued locally |
| Discover | DiscoverModule | Optional | Tab shows installed apps; store disabled |
| Activity | NotificationsModule | Optional | Tab shows "offline" + reconnect button |
| Profile | ProfileModule | Required | Cached profile; "Could not update" toast |

If 0 tabs are available, the app shows a "No modules available — Retry" screen.

## Auth — Decentralized (no Go service)

Auth is handled entirely client-side via `DecentralizedAuthService` in `packages/identity_kernel/`:

| Method | Purpose |
|--------|---------|
| Passkey (WebAuthn) | Primary — biometric login, creates Ed25519 key pair |
| Wallet ZKP | Secondary — zero-knowledge proof challenge signed by wallet |
| Phone (bootstrap) | One-time phone verification, hash committed to chain, phone never used again |

Session: signed 32-byte challenge verified against on-chain Ed25519 public key — no JWT, no auth server.

## Flutter service clients

| Client | File | Purpose |
|--------|------|---------|
| `PasskeyService` | `lib/src/core/services/passkey_service.dart` | WebAuthn platform abstraction |
| `PasskeyService` | `lib/src/core/services/passkey_service.dart` | WebAuthn platform abstraction |

## Onboarding Flow

```
Welcome (/)
  ├─ Browse First → /tour (pre-registration feed)
  │                    └─ Log In / Sign Up → /auth
  ├─ Get Started → /onboarding/phone
  │                    └─ Verify Code → /onboarding/verify
  │                         └─ Username + Display Name → /onboarding/username
  │                              └─ Passkey Create (silent) + Wallet Create (silent)
  │                                   └─ /home (full app)
  └─ Already have account → /auth (unified login)
                              ├─ Register tab → /onboarding/phone
                              ├─ Log In tab → passkey / phone / wallet
                              └─ Wallet tab → ZKP challenge
```

## Key architecture

- **Frontend**: Flutter + flutter_bloc + freezed + go_router + flutter_hooks
- **Decentralization**: Acki Nacki chain (identity, social graph, content hashes) + IPFS (content) — no backend servers
- **Storage**: Hive (local device), IPFS (content-addressed), Acki Nacki chain (authoritative state)
- **Blockchain**: Acki Nacki (invisible wallet via passkey-derived Ed25519 keys)
- **Decentralization**: Chain is authoritative source of truth; Go services are optional relay/indexers (see `DECENTRALIZATION.md`)

## Developer commands

```bash
make bootstrap    # dart pub global activate melos && melos bootstrap
make analyze      # melos exec -- dart analyze .
make test         # melos exec -- dart test
make gen          # regenerate protos + freezed + json_serializable
make dev          # docker compose up --build -d (chat relay only)
make stop         # docker compose down
make lint         # melos exec -- dart analyze .
```

Service ports: chat_relay=8585 (Dart WebSocket relay, anyone can run one).

## Testing without local toolchain

Push to GitHub — CI (`.github/workflows/ci.yml`) runs all Dart + Go tests in the cloud.

For the web app: push to `main` triggers `.github/workflows/deploy-web.yml` which builds the Flutter web app and deploys it to GitHub Pages. You get a live URL to test in your browser — no local install required.

## Code generation

After editing any `@freezed` class or `.proto` file, run `make gen`. Generated files (`*.freezed.dart`, `*.g.dart`, `*.pb.dart`) are gitignored.

## Testing quirks

- Dart tests: `packages/*/test/`
- Flutter E2E: Patrol framework (configured in `apps/mobile/pubspec.yaml`)
- Load testing: k6 (not yet configured)

## Acki Nacki wallet rules

- Username **is** the wallet name on AN chain — must check AN availability before accepting
- Username min **4** characters (not 3)
- Wallet uses **24-word** seed phrase (not 12)
- AN seed phrase **can be changed** — user can rotate in settings
- **No crypto language during onboarding** — no "wallet", "seed phrase", "blockchain" visible in signup flow
- Wallet is auto-created silently when username is accepted
- Seed phrase export is in Profile → Settings → Security (password-gated), never during registration

## Relevant Files

- `/info.md`: authoritative architecture — wallet is part of identity, Identity Kernel is universal user layer.
- `/ARCHITECTURE.md`: full connectable/disconnectable contract, dependency graph, degradation behavior per module.
- `/DECENTRALIZATION.md`: on-chain identity, social graph, content ownership; Go services are optional relay/indexers.
- `/RESEARCH.md`: deep research — Acki Nacki consensus/tokenomics, MPC wallet security, decentralized social patterns, TikTok feed architecture, mini app platforms.
- `/config/features.yaml`: feature flag configuration — every module independently togglable.
- `/apps/mobile/lib/src/core/modules/app_module.dart`: Flutter pluggable module interface — each feature extends AppModule with routes, tab widget, connectivity lifecycle.
- `/apps/mobile/lib/src/core/services/passkey_service.dart`: WebAuthn platform abstraction — biometric passkey create/assert.`
- `/apps/mobile/lib/src/onboarding/auth_page.dart`: Unified auth — Register / Log In / Wallet tabs on one screen.
- `/apps/mobile/lib/src/onboarding/tour_page.dart`: Pre-registration TikTok-style feed preview with floating auth buttons.
- `/apps/mobile/lib/src/onboarding/phone_entry_page.dart`: International phone input — country code dropdown with 200+ flags, E.164 output, search/filter.
- `/apps/mobile/lib/src/settings/profile_settings_page.dart`: Profile settings — display name editor, profile photo picker, username (immutable), passkey status, seed phrase export (password-gated), seed phrase rotation.
- `/packages/decentralized_chat/`: P2P chat over relays + MLS encryption — `DecentralizedChatService`, `ChatRelayClient`, `ConversationStore`, Hive persistence.
- `/packages/identity_kernel/lib/src/feed/decentralized_feed_service.dart`: Feed from chain events + IPFS + local scoring.
- `/packages/identity_kernel/lib/src/ipfs/ipfs_client.dart`: IPFS upload/download with multi-gateway fallback.
- `/packages/identity_kernel/lib/src/ipfs/profile_service.dart`: Profile stored as IPFS JSON, CID committed on chain.
- `/services/chat_relay/`: Dart WebSocket pub/sub relay — anyone can run, topic-based.

## What not to do

- Do not commit `.env` or secrets
- Do not introduce blockchain RPC calls visible to Flutter — wallet must stay invisible
- Do not add comments to generated files (`*.freezed.dart`, `*.g.dart`, `*.pb.dart`)
- Order matters: `make gen` before `make analyze` after model/proto changes
- Do not add password fields to auth — passkey + ZKP replaces passwords entirely
