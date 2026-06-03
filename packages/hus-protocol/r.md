# Code Review: Human Uniqueness System (HUS)

## Overview

A Rust workspace with two crates (`hus-contract`, `hus-sdk`) implementing a biometric uniqueness middleware for the Acki Nacki blockchain. ~300 lines of code across 5 source files.

---

## Architecture

| Layer | Crate | Description |
|-------|-------|-------------|
| On-chain | `hus-contract` | App registry, ZK verification, scoring |
| Client | `hus-sdk` | Matrix obfuscation, distance computation, mock crypto |
| Spec | `plan.md` | Full protocol blueprint |
| Spec (dup) | `AGENTS.md` | Abbreviated copy of `plan.md` |

## Critical Issues

### 1. Matrix validation bug (`sdk/src/lib.rs:11`)
```rust
if matrix.is_empty() || matrix.len() != 512 {
```
Checks if **row count** is 512. The spec defines a `k x 512` projection matrix where `k = 128`. The check should verify each row has 512 columns, not that there are 512 rows:
```rust
if matrix.is_empty() || matrix[0].len() != 512 {
```

### 2. No `no_std` / WASM compatibility
Neither crate is annotated `#![no_std]`. `hus-contract` uses `std::collections::HashMap` which is unavailable on WASM targets. Both crates will fail `wasm32-unknown-unknown` compilation.

### 3. Scoring logic doesn't match spec
Spec formula (`plan.md:51`):
```
Score = max(0, min(100, (1 - D/T_max) * 100))
```
Implementation (`contracts/src/lib.rs:62-67`) uses a branch instead of the mathematical formula and casts to `u8` (lossy clamp). The threshold comparison on line 62 (`>= threshold` → score 0) duplicates the math logic.

### 4. No actual ZK verification
`execute_uniqueness_assertion` accepts a `bool zk_proof_is_valid` parameter rather than verifying a real proof. The `build_mock_membership_proof` returns static bytes. No ZK circuits (arkworks/halo2) or Poseidon hashing are implemented despite being required by the spec.

### 5. Missing dependencies
- `hus-contract` only has `serde` — no `arkworks`, `halo2`, `poseidon`, or Acki Nacki SDK
- `hus-sdk` has zero dependencies — no `tract`/`onnxruntime` for biometric ingestion

### 6. No tests
Zero unit tests, integration tests, or test modules across the entire workspace.

## Moderate Issues

### 7. Toy commitment function (`sdk/src/crypto.rs:7-14`)
```rust
commitment_buffer[idx % 32] ^= byte_representation[idx % 4];
```
XOR-based "commitment" with collision probability ~1. Not a cryptographic hash. Use a real Poseidon hash or at minimum SHA-256.

### 8. `&'static str` error handling
Hardcoded string errors throughout — should use `thiserror` enum for matchable, serializable errors.

### 9. `Vec<Vec<f32>>` for matrix
Heap-allocated nested vector. Spec demands fixed-size arrays for WASM/no-alloc. Should use `[[f32; 512]; 128]` or `Box<[[f32; K]; 512]>`.

### 10. `execute_uniqueness_assertion` always pushes commitment on unique
If `anonymous_match_detected` is true or score >= 80, the user is rejected. But if both are false, the commitment is **always** pushed with no duplicate check against existing commitments in the registry. This allows trivial replay attacks.

### 11. Duplicate files
`AGENTS.md` is a near-copy of `plan.md` (24 lines vs 190). Creates confusion about which is authoritative.

### 12. No CI/CD
No GitHub Actions, no `rust-toolchain.toml`, no `rustfmt`/`clippy` config.

## Minor Issues

- `VerificationResult.registry_index_committed`: `Option<usize>` leaks internal storage index — violates spec's "no identifiable index" constraint.
- `HusClientEdgeEngine.initialize` takes `Vec<Vec<f32>>` by value but `projection_matrix_space` is never mutated — should take `&[Vec<f32>]` and clone, or better, use a fixed array.
- No `Cargo.lock` tracked.
- No `README.md` for project onboarding.
- Whitepaper (`docs/whitepaper.md`) is only 13 lines — needs expansion to be a genuine whitepaper.

## Summary

| Category | Score |
|----------|-------|
| Architecture | 5/10 — Correct conceptual layering but broken WASM target |
| Correctness | 3/10 — Matrix validation bug, scoring mismatch, replay vuln |
| Crypto | 2/10 — Mock proofs, toy commitment, no real ZK |
| Test Coverage | 0/10 — No tests anywhere |
| Code Quality | 5/10 — Idiomatic Rust but missing error types, no-alloc |

**Verdict:** Good blueprint (plan.md) with a prototype that reflects the spec's structure but has significant correctness bugs, no WASM support, no real cryptography, and zero tests. Needs ~2-3 weeks of focused engineering to reach a v0.1 milestone.
