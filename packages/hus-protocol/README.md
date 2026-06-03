# Human Uniqueness System (HUS)

> Decentralized biometric middleware bridging third-party apps and isolated ledgers via zero-knowledge proofs.

[![CI](https://github.com/anomalyco/hus-protocol/actions/workflows/ci.yml/badge.svg)](https://github.com/anomalyco/hus-protocol/actions/workflows/ci.yml)
![rustc](https://img.shields.io/badge/rustc-stable-lightgrey)
![wasm](https://img.shields.io/badge/target-wasm32--unknown--unknown-purple)

---

## Overview

HUS is an autonomous biometric middleware that lets apps verify **a user is a unique human** without ever learning *which* human they are. It operates on three principles:

| Principle | Mechanism |
|-----------|-----------|
| **No identity ownership** | HUS is an algorithmic evaluator — unlink it and apps lose access. |
| **Cross-app unlinkability** | Per-app matrix projection guarantees different apps see different data. |
| **Anonymous dedup** | ZK group membership proofs reject duplicates without revealing identities. |

**Architecture:** `App → HUS → Blockchain`

---

## Quick Start

### Prerequisites

- Rust stable (`rustup default stable`)
- WASM target: `rustup target add wasm32-unknown-unknown`

### Build

```bash
cargo build --release
```

### Test

```bash
cargo test
```

### WASM check (no_std)

```bash
cargo check --no-default-features --target wasm32-unknown-unknown -p hus-contract
cargo check --no-default-features --target wasm32-unknown-unknown -p hus-sdk
```

---

## Repository Structure

```
hus-protocol/
├── Cargo.toml           # Workspace root
├── rust-toolchain.toml  # Stable Rust + WASM target
├── contracts/           # On-chain Acki Nacki contract
│   ├── Cargo.toml
│   └── src/
│       └── lib.rs       # Registry, scoring, verification
├── sdk/                 # Client-side SDK
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs       # Matrix projection, distance
│       ├── crypto.rs    # SHA-256 commitment, mock ZK proof
│       ├── config.rs    # Tunable parameters
│       └── error.rs     # Error types
├── examples/            # Integration examples
│   └── basic_integration.rs
├── docs/
│   ├── whitepaper.md    # Full protocol specification
│   ├── architecture.md  # System architecture
│   ├── api.md           # API reference (JSON-RPC + Rust)
│   ├── integration.md   # Third-party integration guide
│   └── security.md      # Security & threat model
├── plan.md              # Original protocol blueprint
└── AGENTS.md            # AI agent instructions
```

---

## Integration (5-Minute)

Add HUS to your Rust application:

```toml
[dependencies]
hus-sdk = { git = "https://github.com/anomalyco/hus-protocol" }
```

```rust
use hus_sdk::{HusClient, crypto, RAW_DIM, PROJ_DIM};

fn main() -> Result<(), hus_sdk::SdkError> {
    // 1. Load the app-specific projection matrix from chain
    let matrix: [[f32; RAW_DIM]; PROJ_DIM] = load_matrix_from_seed(&[0u8; 32]);

    // 2. Initialize client
    let client = HusClient::new("my_app".into(), matrix);

    // 3. Obfuscate biometric data
    let raw_biometric = extract_face_embedding(&capture);
    let isolated = client.apply_matrix_isolation(&raw_biometric);

    // 4. Compute on-chain commitment
    let commitment = crypto::commit_isolated_vector(&isolated);

    // 5. Generate ZK proof
    let proof = crypto::build_mock_proof(&commitment);

    // 6. Submit to chain (JSON-RPC)
    submit_proof(app_id, user_account, proof, commitment, distance);

    Ok(())
}
```

See the [integration guide](docs/integration.md) for full details, and the [examples](./sdk/examples/) directory for runnable code.

---

## API Overview

### JSON-RPC (Blockchain Interface)

| Method | Description |
|--------|-------------|
| `hus_getAppMatrixSeed` | Retrieve per-app projection seed from chain state |
| `hus_submitUniquenessProof` | Submit ZK proof + commitment for verification |

### Rust SDK

| Function | Description |
|----------|-------------|
| `HusClient::new(app_id, matrix)` | Initialize SDK client |
| `client.apply_matrix_isolation(raw)` | Obfuscate biometric vector |
| `HusClient::euclidean_distance(a, b)` | Compute L2 distance |
| `crypto::commit_isolated_vector(vec)` | SHA-256 commitment |
| `HusContract::verify_uniqueness(...)` | On-chain verification |

---

## Benchmarks

| Operation | Time (approx) | Allocation |
|-----------|--------------|------------|
| Matrix projection (128×512) | ~15 µs | 0 (stack) |
| Euclidean distance (128-dim) | ~0.5 µs | 0 (stack) |
| SHA-256 commitment | ~2 µs | 0 (stack) |

*Measured on Intel i7-12700. WASM targets may vary by ~2-5×.*

---

## Security

- **Privacy:** Raw biometrics never leave the device. Only obfuscated commitments reach the chain.
- **Unlinkability:** Different apps get different projection seeds → different obfuscated vectors.
- **Anonymity:** ZK group membership proofs conceal which account triggered a rejection.

See [security.md](docs/security.md) for the full threat model.

---

## Roadmap

| Phase | Status |
|-------|--------|
| Phase 1: Workspace & deps | ✅ Complete |
| Phase 2: Client SDK | ✅ Complete |
| Phase 3: Smart contract | ✅ Complete |
| Phase 4: ZK circuit integration | ⏳ In progress |
| Phase 5: Acki Nacki deployment | 📅 Planned |
| Phase 6: Mobile engine (NEON/AVX) | 📅 Planned |

---

## License

MIT License. See `LICENSE` for details.
