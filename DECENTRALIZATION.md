# NotJustDex — Decentralization Architecture

## Core Principle

**No single entity or group can control, decide, or shut down NotJustDex.**

The app is unstoppable because:
- **Identity** lives on Acki Nacki chain (no registrar can deny you)
- **Auth** uses passkey + wallet ZKP (no password server to shut down)
- **Messaging** goes P2P via Waku (no relay to seize)
- **Content** is on IPFS (no server to DMCA)
- **Feed** is computed locally from chain events (no algorithm to manipulate)

Every Go service in this repo is **legacy**. The app must work without any of them.

---

## The Stack (Bottom to Top)

```
┌──────────────────────────────────────────────────────────┐
│                    Flutter App                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │              DecentralizedAuthService              │  │
│  │  • Passkey (primary auth, biometric)               │  │
│  │  • Wallet ZKP (secondary, on-chain signature)      │  │
│  │  • Phone (optional bootstrap, fades after reg)     │  │
│  │  • Session = signed challenge (no JWT)             │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │              OnChainIdentityService                 │  │
│  │  • Register identity on AN chain (no relay)        │  │
│  │  • Resolve username → address                      │  │
│  │  • Follow/unfollow (on-chain tx)                   │  │
│  │  • Post content hash (on-chain tx)                 │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │              WalletService (Passkey-Derived)        │  │
│  │  • Seed from passkey credential ID                 │  │
│  │  • Ed25519 key pair from seed                      │  │
│  │  • Sign challenges, not raw txs                    │  │
│  │  • MPC-like: device key is passkey itself          │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │              AnLightClient + IdentityContract       │  │
│  │  • Direct RPC to AN chain (any endpoint)           │  │
│  │  • Fallback list of RPC endpoints                  │  │
│  │  • Subscribe to chain events                       │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │              Local Store (Isar/Hive)                │  │
│  │  • Cached identity                                 │  │
│  │  • Pending transactions (offline queue)            │  │
│  │  • Encrypted session challenge                     │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

---

## Auth Flow (Fully Decentralized)

### Registration
```
1. Tour feed (no auth needed)
2. Enter phone (optional — sybil resistance only)
   → Phone hash committed to chain (NOT the number itself)
   → Verification code sent via any available SMS gateway
   → User enters code → phone hash verified locally
   → Phone impact fades: never used again
3. Create passkey (WebAuthn biometric)
   → Passkey credential ID derived into wallet seed
4. Choose username + display name
   → Username checked on AN chain directly (RPC)
5. Wallet auto-created silently (from passkey seed)
6. Identity registered on AN chain:
   { username, wallet_address, public_key, identity_root, passkey_public_key, phone_hash? }
7. Session = signed challenge (no JWT, no auth server)
```

### Login
```
1. Passkey assertion (biometric)
2. Recover wallet key from passkey credential ID
3. Sign challenge with wallet Ed25519 key
4. Verify signature on chain (getPublicKey → Ed25519.verify)
5. Session = signed challenge, cached locally
```

### Wallet ZKP Login (Alternative)
```
1. User provides wallet address
2. App generates random challenge
3. User signs with their wallet (external signer or MPC)
4. App verifies signature against on-chain public key
5. Session established
```

---

## Phone: Bootstrap Only, Not Identity

Phone is used ONCE for sybil resistance, then discarded.

```
Registration:
  phone → hash + salt → SHA256 → phone_hash → committed on chain
  phone itself NEVER stored, NEVER used as identifier
  
Login:
  Phone NEVER used. Passkey or wallet only.
  
Recovery:
  Seed phrase (24 words) or cloud share.
  Phone can optionally reconfirm (same hash check).
```

Phone verification is decentralized by design:
- Any SMS gateway can be used (user picks; no single provider)
- Verification code is computed locally (hash(phone + nonce))
- The verification proof is the commitment on chain
- If SMS gateways are unavailable, user can skip phone entirely
- Phone is NOT sybil-proof, just sybil-resistant — wallet creation fee on AN chain is the real sybil barrier

---

## Sessions (No JWT, No Server)

Traditional JWT requires a validating server → central point of failure.

NotJustDex sessions are **signed challenges**:

```
1. App generates random 32-byte challenge
2. Wallet signs challenge with Ed25519
3. Challenge + signature + address = session token
4. Verification: fetch public key from chain, Ed25519.verify
5. No server needed — validation is local or on-chain
```

Session token structure:
```dart
class SignedChallenge {
  String address;        // AN wallet address
  List<int> challenge;   // 32 random bytes
  List<int> signature;   // Ed25519 signature
  DateTime timestamp;    // session start
}
```

No expiry server-side. Session expiry is local (app can enforce 24h offline, 7d online).
Re-authentication = new challenge signed by same key.

---

## Data Layer

| Data | Storage | How |
|------|---------|-----|
| Identity | Acki Nacki chain + local Hive | Register via direct RPC; cache locally |
| Public key per identity | Acki Nacki chain | Stored at registration, queriable |
| Username → address | Acki Nacki chain | On-chain mapping |
| Follow graph | Acki Nacki chain | on-chain `follow()` tx |
| Profile metadata | IPFS (CID on chain) | Profile JSON → IPFS → CID stored on chain |
| Content posts | IPFS | Media → IPFS → CID on chain |
| DMs | Waku (P2P encrypted) | X3DH + Double Ratchet over Waku relay |
| Feed | Local computation | Chain events → local scoring → sorted |
| Notifications | Waku Store + chain events | Polled locally, no push server |
| Session | Local Hive | Encrypted at rest |

---

## Service Elimination — DONE

All Go services have been deleted. The decentralized replacements are fully implemented:

| Old Go Service | Replaced By | Status |
|----------------|-------------|--------|
| `services/auth/` | `DecentralizedAuthService` + passkey + AN chain | Done |
| `services/users/` | `AnIdentityContract` + IPFS profile | Done |
| `services/feed/` | `DecentralizedFeedService` + IPFS + chain events | Done |
| `services/chat/` | `DecentralizedChatService` + relays + MLS | Done |
| `services/notifications/` | Local chain event subscription | Done |
| `services/media/` | Direct IPFS upload via `IpfsClient` | Done |
| `services/search/` | Local Hive/Isar full-text search | Pending |
| `services/moderation/` | Client-side blocklist + on-chain reporting | Pending |
| `services/creator_economy/` | Direct AN chain txs | Pending |
| `services/analytics/` | None (no tracking) | Done |
| `services/dao/` | Direct AN chain contract queries | Pending |
| `lib/go/` | Unused (was Go relay library) | Done |

The only remaining infrastructure service is `services/chat_relay/` — a Dart WebSocket pub/sub server that anyone can run.

---

## Threat Model

| Threat | Mitigation |
|--------|------------|
| AN chain halted | App still works for cached content + offline ops. Registration paused. |
| IPFS gateway down | Content from other peers / cached locally |
| SMS gateway down | Phone registration skipped; passkey-only still works |
| Passkey lost | Seed phrase recovery (24 words) + cloud share |
| Phone compromised | Passkey is biometric-locked. Wallet ops need signing. |
| RPC endpoint blocked | Fallback endpoint list; user can configure their own |
| All RPCs blocked | App works with cached data; can't submit new txs |
| Sybil attack | Wallet creation costs gas on AN chain (economic barrier) |
| Spam | On-chain rate limiting + content moderation commitments |

---

## Key Design Decisions

1. **No JWT ever** — signed challenges validated on chain
2. **Passkey is primary identity** — wallet key derived from passkey credential ID
3. **Phone is throwaway** — used once for sybil resistance, committed as hash, never used again
4. **AN chain is source of truth** — not a database, not a Go service
5. **Every user can self-host** — RPC endpoint, IPFS node, Waku node
6. **No feature flags for decentralization** — the app IS decentralized; there's no "optional"
7. **Go services are deleted** — not made optional, not kept for convenience

---

## What Remains "Centralized" (Accepted Tradeoffs)

| Dependency | Why | Decentralized Alternative |
|------------|-----|--------------------------|
| AN RPC endpoint | Chain access | User runs own AN node |
| IPFS gateway | Content availability | User runs own IPFS node |
| SMS gateway | Phone verification | Skip phone; passkey-only |
| App stores | Distribution | F-Droid, direct APK |
| DNS | Domain resolution | IPNS, ENS, AN naming |

None of these are **control points**. Anyone can run their own AN node, IPFS node, or build from source.
NotJustDex cannot be shut down because there is no server to seize, no API key to revoke, no company to sue.
