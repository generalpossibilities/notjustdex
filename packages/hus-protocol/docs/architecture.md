# HUS System Architecture

## 1. Overview

HUS follows a strict three-layer architecture:

```
┌─────────────────────────────────────────────────────┐
│                Application Layer                      │
│  (Third-party dApps: DAOs, games, social platforms)  │
├─────────────────────────────────────────────────────┤
│                 HUS Middleware                        │
│  ┌──────────────────┐   ┌────────────────────────┐  │
│  │  Client SDK       │   │  Smart Contract        │  │
│  │  (on-device)      │   │  (on-chain)            │  │
│  ├──────────────────┤   ├────────────────────────┤  │
│  │ • Biometric       │   │ • App registry         │  │
│  │   ingestion       │   │ • Proof verification   │  │
│  │ • Matrix          │   │ • Score computation    │  │
│  │   projection      │   │ • State mutation       │  │
│  │ • Commitment      │   │ • Event emission       │  │
│  │ • ZK proof gen    │   │                        │  │
│  └──────────────────┘   └────────────────────────┘  │
├─────────────────────────────────────────────────────┤
│              Data Availability Layer                  │
│          (Acki Nacki Blockchain Storage)              │
└─────────────────────────────────────────────────────┘
```

## 2. Layer Responsibilities

### 2.1 Client SDK (`hus-sdk`)

**Purpose:** All privacy-sensitive computation happens here. Raw biometrics never leave this layer.

**Modules:**

| Module | Responsibility |
|--------|---------------|
| `lib.rs` | Core engine: matrix projection, Euclidean distance |
| `crypto.rs` | Commitment hash, mock ZK proof generation |
| `config.rs` | Tunable constants (dimensions, threshold) |
| `error.rs` | Typed error enum |

**Zero-allocation guarantee:** All hot-path operations (projection, distance, commitment) operate on stack-allocated fixed-size arrays (`[f32; 512]`, `[f32; 128]`). No heap allocations occur during biometric processing.

### 2.2 Smart Contract (`hus-contract`)

**Purpose:** Immutable on-chain logic for registry management and uniqueness verification.

**State:** Single `BTreeMap<String, AppRegistry>` mapping app IDs to their registries.

**Entry points:**

- `onboard_app(app_id, owner_pubkey, seed)` — Register a new application
- `verify_uniqueness(app_id, proof_valid, commitment, distance)` — Verify a uniqueness claim

**Execution model:** Designed for Acki Nacki's parallel thread architecture. Each `verify_uniqueness` call is self-contained and operates only on its app's registry, enabling concurrent execution.

### 2.3 JSON-RPC Interface

**Transport:** HTTP/2 to Acki Nacki validator nodes.

**Methods:**

- `hus_getAppMatrixSeed` — Read-only; retrieves per-app seed from chain state
- `hus_submitUniquenessProof` — State-mutating; submits proof for verification

---

## 3. Data Flow (Detailed)

### Registration Flow

```
1. CAPTURE
   App captures biometric via trusted hardware (camera, fingerprint scanner)
   → 512-f32 vector V ∈ [-1.0, 1.0]

2. SEED RETRIEVAL (JSON-RPC)
   App sends: hus_getAppMatrixSeed { app_id }
   Chain returns: seed [u8; 32]
                                              ────
   Derive M_app from seed:
     For i in 0..128:
       For j in 0..512:
         M_app[i][j] = seed_expand(seed, i, j)

3. OBFUSCATION (local, zero-alloc)
   For i in 0..128:
     sum = 0
     For j in 0..512:
       sum += V[j] × M_app[i][j]
     V_obf[i] = sum

4. COMMITMENT (local)
   C = SHA-256(V_obf[0] || V_obf[1] || ... || V_obf[127])

5. ZK PROOF (local)
   π = ZK-Prove{ V_obf such that SHA-256(V_obf) = C }

6. SUBMISSION (JSON-RPC)
   App sends: hus_submitUniquenessProof {
     app_id,
     user_account,
     zk_proof: π,
     new_commitment: C,
     calculated_distance: D
   }

7. VERIFICATION (on-chain)
   Contract:
     a. Load AppRegistry for app_id
     b. Verify ZK proof π
     c. Compute score from D and threshold
     d. Check C ∉ registry.biometric_hashes
     e. If unique: push C, emit success
     f. If duplicate: emit rejection
```

---

## 4. State Machine

```
                  ┌──────────┐
                  │  App not │
                  │ onboarded│
                  └────┬─────┘
                       │ onboard_app()
                       ▼
                  ┌──────────┐
                  │  Active  │
                  │  App     │
                  └────┬─────┘
                       │ verify_uniqueness()
                       ▼
            ┌────────────────────┐
            │  Proof Valid?      │
            ├────────┬───────────┤
            │  No    │  Yes      │
            │  ───   │  ───      │
            │ Error  │  ▼        │
            └────────┘  ┌───────────────────┐
                        │ Score ≥ 80?       │
                        ├───────┬───────────┤
                        │ Yes   │ No        │
                        │ ───   │ ───       │
                        │ Reject│ ▼         │
                        └───────┘ ┌──────────────────┐
                                 │ Duplicate C?      │
                                 ├──────┬────────────┤
                                 │ Yes  │ No         │
                                 │ ───  │ ───        │
                                 │ Rej. │ Push C     │
                                 └──────┴────────────┘
```

---

## 5. Concurrency Model

Acki Nacki executes smart contracts in parallel threads. HUS is designed to maximize thread-level parallelism:

- **No cross-app contention:** Each app has its own `AppRegistry`. Verification for App A and App B can run in parallel.
- **No global state:** The only shared state is the `app_directory` map, which is accessed by `app_id` key — a natural partition.
- **Read-only seeds:** `hus_getAppMatrixSeed` is a pure read and never contends with writes.

---

## 6. Security Boundaries

```
┌──────────────────────────────────────┐
│  Trusted: User Device                 │
│  (biometric capture, SDK execution)  │
├──────────────────────────────────────┤
│  Trusted but verifiable: Acki Nacki  │
│  (smart contract execution)          │
├──────────────────────────────────────┤
│  Untrusted: Network, validators      │
│  (assumes honest majority)           │
└──────────────────────────────────────┘
```

- Biometric capture must occur on a trusted path (hardware-validated sensor).
- SDK execution is on the user's device — assumed trusted by the user, untrusted by the protocol.
- Smart contract execution is verified by the Acki Nacki consensus protocol.
