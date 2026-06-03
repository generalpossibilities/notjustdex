# HUS Integration Guide

This guide walks through integrating HUS into a third-party application. HUS is agnostic to the application type — it works with DAOs, games, social platforms, or any dApp requiring Sybil resistance.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Architecture Overview](#2-architecture-overview)
3. [Step-by-Step Integration](#3-step-by-step-integration)
4. [Mobile Integration](#4-mobile-integration)
5. [Testing](#5-testing)
6. [Best Practices](#6-best-practices)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Prerequisites

### On-Chain

- An Acki Nacki validator node with a JSON-RPC endpoint
- A registered app entry (via `hus_onboardApp` or equivalent)
- The app's 32-byte matrix projection seed

### Client-Side

- Rust `stable` toolchain
- WASM target: `rustup target add wasm32-unknown-unknown`
- Biometric capture capability (camera for face, scanner for fingerprint)

---

## 2. Architecture Overview

```
Your App (Rust/JS/Mobile)
    │
    ├── [Device] Capture biometric → raw vector [f32; 512]
    ├── [SDK]   Apply matrix isolation → obfuscated [f32; 128]
    ├── [SDK]   Commit via SHA-256 → [u8; 32]
    ├── [SDK]   Generate ZK proof (mock or real)
    └── [RPC]   Submit proof to Acki Nacki → verification result
```

---

## 3. Step-by-Step Integration

### 3.1 Add Dependency

**Rust (Cargo.toml):**

```toml
[dependencies]
hus-sdk = { git = "https://github.com/anomalyco/hus-protocol" }
hus-contract = { git = "https://github.com/anomalyco/hus-protocol" }
```

**JavaScript (WASM):**

```bash
npm install @anomalyco/hus-sdk
```

> *Note: WASM bindings are in development. Currently only native Rust is supported.*

### 3.2 Initialize the Client

```rust
use hus_sdk::{HusClient, config, RAW_DIM, PROJ_DIM};

// Load the projection matrix from the chain seed
fn load_matrix(app_id: &str) -> [[f32; RAW_DIM]; PROJ_DIM] {
    let seed = fetch_seed_from_chain(app_id);
    expand_seed_to_matrix(&seed)
}

let client = HusClient::new(
    "my_app_id".into(),
    load_matrix("my_app_id"),
);
```

### 3.3 Process Biometric Data

```rust
// Raw biometric from trusted hardware (normalized to [-1, 1])
let raw_biometric: [f32; RAW_DIM] = capture_biometric();

// Obfuscate via matrix projection
let isolated = client.apply_matrix_isolation(&raw_biometric);

// Compute commitment
let commitment = hus_sdk::crypto::commit_isolated_vector(&isolated);
```

### 3.4 Generate Proof

```rust
// For production: replace with Halo2/Arkworks prover
let proof = hus_sdk::crypto::build_mock_proof(&commitment);
```

### 3.5 Submit to Chain

```rust
// Compute distance to nearest existing entry
// (in production, this happens inside the ZK circuit)
let self_distance = HusClient::euclidean_distance(&isolated, &isolated);

// JSON-RPC payload
let payload = serde_json::json!({
    "jsonrpc": "2.0",
    "id": 1,
    "method": "hus_submitUniquenessProof",
    "params": {
        "app_id": "my_app_id",
        "user_account": user_account,
        "zk_proof": hex::encode(&proof),
        "new_commitment": hex::encode(&commitment),
        "calculated_distance": self_distance,
    }
});

let response = http_client.post(validator_url, payload).await?;
```

### 3.6 Handle Response

```rust
match response.status.as_str() {
    "success" => {
        println!(
            "User registered. Score: {}, Registry: {}",
            response.uniqueness_score,
            if response.registry_updated { "UPDATED" } else { "REJECTED" }
        );
    }
    "error" => {
        eprintln!("Verification failed: {}", response.message);
    }
}
```

---

## 4. Mobile Integration

### 4.1 iOS

Compile `hus-sdk` as an XCFramework:

```bash
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
xcodebuild -create-xcframework ...
```

### 4.2 Android

Compile for NDK targets:

```bash
cargo build --release --target aarch64-linux-android
cargo build --release --target armv7-linux-androideabi
```

### 4.3 Performance Configuration

Add the following to your `Cargo.toml` for NEON/AVX optimizations:

```toml
[target.'cfg(target_arch = "aarch64")'.rustflags]
rustflags = ["-C", "target-feature=+neon"]

[target.'cfg(target_arch = "x86_64")'.rustflags]
rustflags = ["-C", "target-feature=+avx2"]
```

---

## 5. Testing

### 5.1 Unit Tests

```bash
cargo test -p hus-sdk
cargo test -p hus-contract
```

### 5.2 Integration Test (Full Flow)

See `sdk/examples/basic_integration.rs` for a complete runnable example:

```bash
cargo run --example basic_integration -p hus-sdk
```

### 5.3 WASM Compatibility Check

```bash
cargo check --no-default-features --target wasm32-unknown-unknown -p hus-sdk
cargo check --no-default-features --target wasm32-unknown-unknown -p hus-contract
```

---

## 6. Best Practices

### 6.1 Biometric Capture

- Use hardware-validated peripherals that sign captured data
- Normalize vectors to [-1.0, 1.0] range
- Capture multiple frames and average for noise reduction
- Never store raw biometric data on disk

### 6.2 Network Communication

- Always use HTTPS/TLS for JSON-RPC communication
- Implement retry with exponential backoff for network failures
- Cache the app's projection seed locally (it's immutable)
- Verify transaction hash in the response

### 6.3 Error Handling

- Handle `InvalidProof` errors by re-capturing biometrics
- Handle `DuplicateCommitment` by informing user they're already registered
- Handle `AppNotFound` by contacting the app developer

### 6.4 Production Deployment

- Replace `build_mock_proof` with a real prover (Halo2/Arkworks)
- Set calibration threshold based on your security requirements
- Monitor verification events on-chain
- Regular security audits

---

## 7. Troubleshooting

| Symptom | Likely Cause | Solution |
|---------|-------------|----------|
| `App not found` | App not onboarded | Register the app via `hus_onboardApp` |
| `Invalid proof` | Corrupted proof data | Regenerate proof with fresh capture |
| `Dimension mismatch` | SDK version mismatch | Update to matching SDK/contract versions |
| High rejection rate | Threshold too strict | Increase calibration threshold |
| Low matching accuracy | Poor biometric capture | Check hardware, improve capture conditions |
| Build fails on WASM | Missing no_std features | Use `--no-default-features` flag |
