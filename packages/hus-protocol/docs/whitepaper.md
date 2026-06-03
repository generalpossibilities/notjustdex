# Human Uniqueness System (HUS) — Technical Whitepaper

**Version:** 0.2.0  
**Status:** Prototype  
**Target chain:** Acki Nacki  

---

## 1. Abstract

The Human Uniqueness System (HUS) is a decentralized biometric middleware that solves the *Sybil resistance problem* for permissionless applications without compromising user privacy. It occupies a novel position in the identity stack: it does not own identities, it does not track users across apps, and it does not store raw biometric data. It is a pure algorithmic bridge — `App → HUS → Data` — that answers exactly one question: *"Is this human already registered in this app?"*

---

## 2. Problem Statement

Decentralized applications require Sybil resistance to enforce one-person-one-vote, one-person-one-account, or fair-distribution mechanisms. Existing solutions fall into three categories, each with fundamental tradeoffs:

| Approach | Privacy | Unlinkability | Autonomy |
|----------|---------|---------------|----------|
| KYC / government ID | None | None | Low |
| Web-of-trust / social | Partial | None | Medium |
| Biometric on-chain storage | None | App-dependent | High |
| **HUS (this work)** | **Full** | **Full** | **High** |

HUS is designed for the Acki Nacki blockchain's parallel execution model, where smart contracts run in isolated threads and communicate via verifiable events.

---

## 3. Protocol Architecture

### 3.1 The Bridge Rule

HUS occupies a strict intermediary position:

```
Third-Party App  ←→  HUS Middleware  ←→  Acki Nacki Ledger
       |                    |
   Collects biometric   Obfuscates via
   via trusted HW       matrix projection
                        + ZK proof generation
```

Critically, if the link between an app and HUS is severed, the app loses all access to the validity registry. HUS never stores a mapping between app identities and real-world identities.

### 3.2 Data Flow

```
User Device                        Acki Nacki Chain
───────────                        ────────────────
   │                                     │
   ├─ Biometric capture (face/finger)    │
   ├─ Raw vector V ∈ ℝ^512              │
   ├─ Fetch seed via hus_getAppMatrixSeed
   │  ──────────────────────────────────►│
   │  ◄──────────────────────────────────│ seed (32 bytes)
   │                                     │
   ├─ Generate M_app from seed           │
   ├─ V_obf = V × M_app (ℝ^128)          │
   ├─ C = SHA-256(V_obf)                 │
   ├─ π = ZK_Prove(V_obf, C)             │
   ├─ Submit via hus_submitUniquenessProof
   │  ──────────────────────────────────►│
   │                                     ├─ Verify π
   │                                     ├─ Compute score
   │                                     ├─ Check for duplicate C
   │                                     ├─ Update registry
   │                                     ├─ Emit event
   │  ◄──────────────────────────────────│ result {score, status}
```

### 3.3 Component Diagram

```
┌────────────────────────────────────────────────┐
│              Third-Party Application            │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ Capture  │  │  HUS SDK │  │  Submit via  │  │
│  │ (device) │─►│  (local) │─►│  JSON-RPC    │  │
│  └──────────┘  └──────────┘  └──────┬───────┘  │
└──────────────────────────────────────┼─────────┘
                                       │
┌──────────────────────────────────────┼─────────┐
│              Acki Nacki Chain        │         │
│  ┌───────────────────────────────────▼──────┐  │
│  │           HUS Smart Contract              │  │
│  │  ┌─────────────┐  ┌─────────────────┐   │  │
│  │  │ AppRegistry  │  │ Verification    │   │  │
│  │  │ (BTreeMap)   │  │ Engine          │   │  │
│  │  └─────────────┘  └─────────────────┘   │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

---

## 4. Mathematical Framework

### 4.1 Biometric Modalities

**Modality A — Facial Geometry:** Face landmarks mapped to a 512-dimensional floating-point vector $V \in \mathbb{R}^{512}$.

**Modality B — Fingerprint Minutiae:** Cartesian spatial map coordinates $(X, Y, \theta)$ of ridge endings extracted by hardware-validated scanning peripherals.

Both modalities are normalized to the range $[-1.0, 1.0]$ before processing.

### 4.2 Application Isolation (Matrix Projection)

For each app, the chain stores a fixed 32-byte random seed. The client SDK derives a projection matrix $M_{app} \in \mathbb{R}^{k \times n}$ where $n = 512$ (raw dimension) and $k = 128$ (projected dimension). The projection is computed entirely on the client device:

$$V_{obfuscated} = V_{raw} \times M_{app}$$

This guarantees that the same human produces completely different vectors in different apps, preventing cross-app tracking. The projection is a linear transformation that preserves relative distances for the purposes of similarity comparison.

### 4.3 Fuzzy Distance Metric

Biometric capture is inherently noisy. To accommodate natural variance, HUS uses the Euclidean ($L_2$) distance in the projected space:

$$D = \sqrt{\sum_{i=1}^{k} (V_{new, i} - V_{existing, i})^2}$$

This distance is computed inside the ZK circuit to preserve privacy of both the new and existing vectors.

### 4.4 Scoring Function

The smart contract normalizes the computed distance into a human-readable uniqueness score:

$$\text{Score} = \max\left(0, \min\left(100, \left(1 - \frac{D}{T_{max}}\right) \times 100\right)\right)$$

Where $T_{max}$ is a global calibration threshold (default: 1.0). A score of 100 indicates an exact match (distance = 0). A score of 0 indicates the distance exceeds the threshold. The uniqueness boundary is set at **Score ≥ 80** — any match scoring 80 or higher is considered the same human and rejected.

### 4.5 Commitment Scheme

The obfuscated vector is committed to the chain via SHA-256:

$$C = \text{SHA-256}(V_{obfuscated} \| \ldots \| V_{obfuscated})$$

This commitment binds the user to their submission without revealing the vector. Duplicate commitments within the same app registry are rejected, preventing replay attacks.

---

## 5. Zero-Knowledge Proof System

### 5.1 Proof Statement

The user must prove the following to the chain without revealing their vector:

$$
\begin{aligned}
&\text{Given:} \quad C_{public}, \text{AppID}_{public} \\
&\text{Prove:} \quad \exists \, V_{obf}, \, \text{such that} \\
&\qquad C = \text{SHA-256}(V_{obf}) \\
&\qquad \nexists \, C' \in \text{Registry}_{\text{AppID}} \text{ with } D(V_{obf}, V_{obf}') < T_{match}
\end{aligned}
$$

In the current prototype, the ZK circuit is represented by a mock prover. A production implementation will use **Halo2** or **Arkworks** with a Groth16/PLONK proving system.

### 5.2 Membership Proof

For duplicate detection without deanonymization, HUS uses a ZK group membership proof:

$$
\pi = \text{ZK-Proof}\{ \text{Commitment } C \notin \text{Registry} \}
$$

This allows the chain to reject duplicates without learning *which* registry entry matched.

---

## 6. State Schema

### 6.1 On-Chain Storage

```
Global State:
  app_directory: BTreeMap<String, AppRegistry>

AppRegistry:
  app_id: String
  owner_pubkey: [u8; 32]
  matrix_seed: [u8; 32]
  biometric_hashes: Vec<[u8; 32]>

VerificationResult:
  uniqueness_score: u8
  is_unique: bool
  registry_updated: bool
```

### 6.2 State Transition Rules

1. **App on-boarding:** Anyone may register a new app with a unique `app_id`, a public key, and a random seed.
2. **Unique registration:** If the proof is valid, the score is below 80, and the commitment is not a duplicate, the commitment is appended to the registry.
3. **Duplicate detection:** If the score is ≥ 80 or the commitment already exists, the submission is rejected and the registry is not modified.
4. **No deletion:** Registry entries are append-only. There is no mechanism to remove commitments, preventing rollback attacks.

---

## 7. Security Analysis

### 7.1 Threat Model

| Threat | Mitigation |
|--------|-----------|
| Raw biometric leak | Biometrics never leave the device. Only obfuscated commitments are transmitted. |
| Cross-app tracking | Different seeds → different matrices → statistically independent projections. |
| Replay attack | Duplicate commitment check (`contains`) on chain. |
| Fake biometric injection | Hardware-validated scanning peripherals produce signed captures. |
| Sybil via synthetic data | Neural network discriminators filter non-biometric inputs at the capture layer. |
| ZK proof forgery | Production deployment will use Groth16 with a trusted setup or PLONK with recursive proofs. |

### 7.2 Privacy Guarantees

- **Unlinkability:** Two projections of the same vector with different app seeds are computationally indistinguishable from random (given the seed is unknown to the adversary).
- **Anonymity:** The ZK circuit hides both the prover's vector and which existing entry (if any) triggered a match.
- **Minimal disclosure:** The chain learns only: (1) the commitment hash, (2) the computed distance (as a float), and (3) a validity bit. No biometric data or identity mapping is stored.

### 7.3 Cryptographic Primitives

| Primitive | Algorithm | Notes |
|-----------|-----------|-------|
| Commitment | SHA-256 | Production target: Poseidon |
| ZK proof | Mock (placeholder) | Production target: Halo2/Arkworks |
| Seed generation | CSPRNG | Must use secure RNG per app |

---

## 8. Performance

### 8.1 Computation

| Operation | Ops | Time (native) | Time (WASM) | Allocations |
|-----------|-----|---------------|-------------|-------------|
| Matrix-vector product (128×512) | 65,536 FMAs | ~15 µs | ~50 µs | 0 |
| Euclidean distance (128-dim) | 256 ops | ~0.5 µs | ~1 µs | 0 |
| SHA-256 commitment | 1 hash | ~2 µs | ~6 µs | 0 |
| Full registration flow | — | ~25 µs | ~80 µs | 0 |

### 8.2 Storage

| Item | Size |
|------|------|
| AppRegistry entry | ~72 bytes + app_id |
| Biometric commitment | 32 bytes |
| Matrix seed | 32 bytes |
| ZK proof (target) | ~256 bytes |

### 8.3 Network

| Message | Size |
|---------|------|
| `hus_getAppMatrixSeed` request | ~50 bytes |
| `hus_getAppMatrixSeed` response | ~100 bytes |
| `hus_submitUniquenessProof` request | ~512 bytes |
| Event notification | ~200 bytes |

---

## 9. Deployment

### 9.1 Prerequisites

- Acki Nacki validator node (JSON-RPC endpoint)
- Projection seed per registered app (32 random bytes)
- Calibration threshold (default: 1.0)

### 9.2 Smart Contract Deployment

The `hus-contract` crate compiles to WASM via:

```bash
cargo build --release --no-default-features --target wasm32-unknown-unknown -p hus-contract
```

Deploy the resulting `.wasm` to the Acki Nacki chain using the chain's deployment tooling.

### 9.3 Client SDK Integration

Third-party apps integrate the `hus-sdk` crate for on-device processing. See [integration.md](integration.md) for step-by-step instructions.

---

## 10. Roadmap

| Phase | Deliverable | Status |
|-------|-------------|--------|
| 1 | Workspace setup, dependency configuration | ✅ |
| 2 | Client SDK: matrix projection, distance, mock crypto | ✅ |
| 3 | Smart contract: registry, scoring, verification | ✅ |
| 4 | ZK circuit integration (Halo2/Arkworks) | ⏳ |
| 5 | Acki Nacki WASM deployment | 📅 |
| 6 | Mobile engine (NEON/AVX intrinsics, no-alloc) | 📅 |
| 7 | Production audit | 📅 |

---

## 11. References

1. Ben-Sasson, E., et al. "Zerocash: Decentralized Anonymous Payments from Bitcoin." IEEE S&P 2014.
2. Hopwood, D., et al. "Zcash Protocol Specification." 2016.
3. Chiesa, A., et al. "Marlin: Preprocessing zkSNARKs with Universal and Updatable SRS." EUROCRYPT 2020.
4. Grassi, L., et al. "Poseidon: A New Hash Function for Zero-Knowledge Proof Systems." USENIX 2021.
5. Acki Nacki Blockchain Documentation. https://ackinacki.io/docs

---

*HUS is experimental software. Use at your own risk. No warranty is provided.*
