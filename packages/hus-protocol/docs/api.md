# HUS API Reference

## 1. JSON-RPC Interface

Communication between third-party applications and Acki Nacki validator nodes uses JSON-RPC 2.0 over HTTP/2.

### 1.1 `hus_getAppMatrixSeed`

Retrieves the application's unique public seed from the blockchain state to generate the client-side matrix projection.

**Request:**

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

**Response:**

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

**Error codes:**

| Code | Message | Description |
|------|---------|-------------|
| -32000 | App not found | No registry exists for the given app_id |
| -32602 | Invalid params | app_id is empty or malformed |

### 1.2 `hus_submitUniquenessProof`

Submits the generated Zero-Knowledge proof and public commitments to the Acki Nacki parallel execution thread for validation.

**Request:**

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

**Response (Emitted Event via Callback):**

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

**Error codes:**

| Code | Message | Description |
|------|---------|-------------|
| -32000 | App not found | No registry exists for the given app_id |
| -32001 | Invalid proof | ZK proof verification failed |
| -32002 | Duplicate registration | User already registered (score ≥ 80) |
| -32003 | Rejected by calibration | Distance exceeds calibration threshold |

---

## 2. Rust SDK API (`hus-sdk`)

### 2.1 Type Aliases

```rust
pub const RAW_DIM: usize = 512;   // Raw biometric dimension
pub const PROJ_DIM: usize = 128;  // Projected (obfuscated) dimension
```

### 2.2 `HusClient`

The core client engine for on-device biometric processing.

```rust
impl HusClient {
    /// Create a new HUS client with a fixed projection matrix.
    pub fn new(app_id: String, matrix: [[f32; RAW_DIM]; PROJ_DIM]) -> Self;

    /// Apply app-specific matrix projection to obfuscate biometric data.
    /// Returns a fixed-size [f32; 128] array (zero-allocation).
    ///
    /// # Arguments
    /// * `raw` - Raw 512-dimensional biometric vector, normalized to [-1, 1]
    ///
    /// # Returns
    /// * `[f32; PROJ_DIM]` - Obfuscated 128-dimensional vector
    pub fn apply_matrix_isolation(&self, raw: &[f32; RAW_DIM]) -> [f32; PROJ_DIM];

    /// Compute Euclidean (L2) distance between two projected vectors.
    ///
    /// # Arguments
    /// * `a` - First projected vector
    /// * `b` - Second projected vector
    ///
    /// # Returns
    /// * `f32` - Non-negative distance
    pub fn euclidean_distance(a: &[f32; PROJ_DIM], b: &[f32; PROJ_DIM]) -> f32;
}
```

### 2.3 Crypto Module

```rust
/// Compute a SHA-256 commitment over arbitrary byte data.
pub fn hash_commitment(data: &[u8]) -> [u8; 32];

/// Compute a SHA-256 commitment over a projected biometric vector.
/// Serializes each f32 as its 4-byte little-endian representation before hashing.
pub fn commit_isolated_vector(vec: &[f32; PROJ_DIM]) -> [u8; 32];

/// Build a mock ZK proof for testing.
/// In production, this is replaced by a Halo2/Arkworks prover.
///
/// # Format
/// [32-byte commitment | 1-byte validity flag]
pub fn build_mock_proof(commitment: &[u8; 32]) -> Vec<u8>;

/// Example raw biometric vector (512 f32s all set to 0.0112)
pub const MOCK_RAW_EMBEDDING: [f32; RAW_DIM];
```

### 2.4 Error Types

```rust
pub enum SdkError {
    MatrixDimensionMismatch { expected: usize, got: usize },
    VectorDimensionMismatch { expected: usize, got: usize },
    InvalidSeed,
    CryptoError { reason: &'static str },
}
```

### 2.5 Configuration

```rust
pub struct HusConfig {
    pub raw_dim: usize,           // Default: 512
    pub proj_dim: usize,          // Default: 128
    pub threshold: f32,           // Default: 1.0
    pub uniqueness_min_score: u8, // Default: 80
}
```

---

## 3. Smart Contract API (`hus-contract`)

### 3.1 Types

```rust
pub struct AppRegistry {
    pub app_id: String,
    pub owner_pubkey: [u8; 32],
    pub matrix_seed: [u8; 32],
    pub biometric_hashes: Vec<[u8; 32]>,
}

pub struct VerificationResult {
    pub uniqueness_score: u8,
    pub is_unique: bool,
    pub registry_updated: bool,
}
```

### 3.2 Methods

```rust
impl HusContract {
    /// Create a new contract instance.
    pub fn new(threshold: f32) -> Self;

    /// Register a new application.
    pub fn onboard_app(
        &mut self,
        app_id: String,
        owner: [u8; 32],
        seed: [u8; 32],
    ) -> Result<(), ContractError>;

    /// Verify a uniqueness claim.
    pub fn verify_uniqueness(
        &mut self,
        app_id: &str,
        proof_valid: bool,
        commitment: [u8; 32],
        distance: f32,
    ) -> Result<VerificationResult, ContractError>;

    /// Pure scoring function (no side effects).
    pub fn calculate_score(distance: f32, threshold: f32) -> u8;
}
```

### 3.3 Error Codes

```rust
pub enum ContractError {
    AppNotFound,
    AppAlreadyRegistered,
    InvalidProof,
    DuplicateCommitment,
    DivisionByZero,
}
```

---

## 4. Error Handling Map

| Scenario | Code-level error | JSON-RPC error |
|----------|-----------------|----------------|
| App ID not registered | `ContractError::AppNotFound` | `-32000` |
| App ID already exists | `ContractError::AppAlreadyRegistered` | `-32000` |
| Invalid ZK proof | `ContractError::InvalidProof` | `-32001` |
| Duplicate commitment hash | `ContractError::DuplicateCommitment` | `-32003` |
| Dimension mismatch in SDK | `SdkError::VectorDimensionMismatch` | — |
| Invalid projection seed | `SdkError::InvalidSeed` | — |
