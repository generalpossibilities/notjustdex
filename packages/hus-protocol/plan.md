# AI Agent Execution Blueprint: Human Uniqueness System (HUS)

You are an expert Principal Protocol Engineer specializing in Substrate/Wasm decentralized networks, Rust systems programming, and zero-knowledge cryptographic architectures. Your task is to build HUS (Human Uniqueness System), an autonomous biometric middleware bridging third-party apps and isolated decentralized ledgers over the Acki Nacki blockchain.

---

## 1. Core Architectural Constraints
*   **The Bridge Rule ("APP - HUS - DATA"):** HUS does not permanently own user identities. It operates purely as an algorithmic evaluator. If HUS is unlinked, apps lose access to the underlying validity registries.
*   **Cross-App Unlinkability:** The same biological human MUST yield completely distinct data footprints across App A, App B, and App C. Cross-app user tracking is prevented by performing local matrix obfuscation before generating proofs.
*   **Anonymous Duplication Checks:** If an existing user attempts to register under a new public key/account within the same app, the transaction must be rejected. However, the system must not be able to identify which specific historical account the user originally matched. This anonymity is achieved using Zero-Knowledge Group Membership Proofs.

---

## 2. Target File Tree Schema
Ensure your workspace matches the following structure exactly:
```text
hus-protocol/
├── Cargo.toml
├── contracts/
│   ├── Cargo.toml
│   └── src/
│       └── lib.rs         # On-chain Acki Nacki thread-parallel contract
├── sdk/
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs         # Client-side embedding & matrix transformer
│       └── crypto.rs      # ZK Prover & Poseidon commitment interface
└── AGENTS.md              # This instruction file
```

---

## 3. Mathematical Specifications

### Modality A: Facial Geometry Extraction
Input: Face landmarks mapped to a 512-dimensional floating-point vector $V \in \mathbb{R}^{512}$.

### Modality B: Fingerprint Minutiae Coordinates
Input: Cartesian spatial map coordinates $(X, Y, \theta)$ of ridge endings extracted by hardware-validated scanning peripherals.

### Application Isolation (The Matrix Projection)
For a specific registering App ID, retrieve a fixed random seed from the chain to construct projection matrix $M_{app} \in \mathbb{R}^{k \times n}$. Project the raw vector locally on the client device:
$$V_{obfuscated} = V \times M_{app}$$

### Fuzzy Vector Distance Metric
Biometric variance is resolved by evaluating spatial Euclidean distance ($L_2$ norm) inside a Zero-Knowledge circuit:
$$D = \sqrt{\sum_{i=1}^{k} (V_{new, i} - V_{existing, i})^2}$$

### Dynamic Scoring Function
The smart contract normalizes biometric distance into a 0-100 linear value. Let $T_{max}$ represent the maximum allowable boundary for a match:
$$\text{Score} = \max\left(0, \min\left(100, \left(1 - \frac{D}{T_{max}}\right) \times 100\right)\right)$$

---

## 4. Implementation Phasing Roadmap

### Phase 1: Environment Configuration
*   Establish a multi-package `Cargo.toml` workspace.
*   Import target dependencies optimized for WASM runtimes: `arkworks` or `halo2` for ZK proving systems, `poseidon` for circuit hashing, and standard cryptographic primitives.

### Phase 2: Client SDK Development (`sdk/`)
*   Write a Rust feature module utilizing `tract` or `onnxruntime` bindings to ingest standardized raw biometric data frames.
*   Implement matrix dot-product operations to obscure vectors locally using seeds retrieved from the blockchain.
*   Build the local witness generator that converts raw vector distance calculations into private ZK circuit components.

### Phase 3: Acki Nacki Smart Contract Engine (`contracts/`)
*   Develop an isolated storage schema mapping application identifiers (`String`) to individual vector registries (`Vec<[u8; 32]>`).
*   Implement the primary verification entry-point: accepts incoming ZK proofs, verifies validation states, computes the dynamic 0-100 score, updates registries for unique scores ($\ge 80$), and publishes an on-chain verification payload.

### Phase 4: Verification Pipeline Integration
*   Establish communication bindings connecting client proofs to the Acki Nacki parallel execution thread.
*   Construct mock integration test scripts simulating multiple applications (App A and App B) executing uniqueness assertions for overlapping and unique dummy identities.

---

## 5. Execution Directive
Begin generating files sequentially, starting with the workspace root `Cargo.toml` configurations followed by the client-side vector mechanics. Adhere strictly to zero-allocation operations, complete compilation compatibility with `wasm32-unknown-unknown`, and panic-free smart contract handlers.

## 6. JSON-RPC Interface Specifications
When interacting with Acki Nacki network validator nodes, the HUS client SDK and third-party application backends must communicate via the following structured JSON-RPC methods.

### Method 1: `hus_getAppMatrixSeed`
Retrieves the application's unique public seed from the blockchain state to generate the client-side matrix projection.

**Request Payload:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "hus_getAppMatrixSeed",
  "params": {
    "app_id": "app_alpha_dao_2026"
  }
}
```

**Response Payload:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "app_id": "app_alpha_dao_2026",
    "seed": [14, 99, 214, 88, 45, 112, 9, 201, 33, 47, 88, 192, 5, 66, 12, 90, 81, 4, 11, 76, 54, 98, 23, 190, 44, 3, 89, 101, 220, 11, 5, 74]
  }
}
```

### Method 2: `hus_submitUniquenessProof`
Submits the generated Zero-Knowledge proof and public commitments to the Acki Nacki parallel execution thread for validation.

**Request Payload:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "hus_submitUniquenessProof",
  "params": {
    "app_id": "app_alpha_dao_2026",
    "user_account": "an_account_address_y_abc123...",
    "zk_proof": "0x8aef3d91c002bc45ffeed431102ba98e...",
    "new_commitment": "0x5c7b812a00d234ebfa451c0982ef3b41...",
    "calculated_distance": 0.142
  }
}
```

**Response Payload (Emitted Event via Callback):**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "status": "success",
    "uniqueness_score": 91,
    "registry_updated": true,
    "transaction_hash": "0xbc88231efba49201cdde32b5091a8ecf..."
  }
}
```

---

## 7. Mock Test Datasets
To evaluate system performance and verify calibration scoring thresholds locally, agents should initialize verification pipelines with the following multi-dimensional mock vector datasets.

### Dataset A: Raw Face Geometry Vector (512-Dimensions)
Representing a 512-dimension floating-point array normalized between `-1.0` and `1.0`.
```rust
// Truncated representation for testing configurations
pub const MOCK_RAW_FACE_VECTOR: [f32; 512] = [
    0.0234, -0.1105,  0.5641,  0.0092, -0.3128,  0.8812, -0.0451,  0.1192,
    // ... Middle elements padded with repeatable deterministic signatures ...
    0.1043, -0.0211,  0.4419,  0.0732, -0.1984,  0.6120, -0.0031,  0.0911
];
```

### Dataset B: App-Specific Projection Matrix (k x 512)
Where $k = 128$ dimensions to reduce storage overhead while preserving feature clustering stability.
```rust
// Dynamically generated row structures using App Seed initialization
pub fn generate_mock_app_matrix() -> Vec<Vec<f32>> {
    let mut matrix = vec![vec![0.0; 512]; 128];
    // Seeded linear congruence or standard PRNG implementation
    for i in 0..128 {
        for j in 0..512 {
            matrix[i][j] = ((i * j) as f32 % 100.0) / 100.0; // Deterministic mock floats
        }
    }
    matrix
}
```

---

## 8. Mobile Engine Performance Compilation Optimizations
To compile the client-side feature extraction and local mathematical transformation SDK into low-power iOS/Android wrappers natively without overheating user hardware:

1.  **Strict No-Alloc Vectors:** Avoid runtime dynamic heap scaling allocations within inner loops. Always unpack vectors using fixed-length array references (`&[f32; 512]`).
2.  **NEON / AVX Target Intrinsic Extensions:** Force compiler vectorization routines during deployment compilation inside `Cargo.toml`.
3.  **Optimization Profile Configuration:** Add the following release rules to eliminate unneeded panic handling text blocks and optimize runtime execution code footprints:

```toml
[profile.release]
opt-level = 3
lto = true
codegen-units = 1
panic = 'abort'
```

