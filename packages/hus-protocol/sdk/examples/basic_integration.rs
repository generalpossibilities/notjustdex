/// Basic integration example showing the full HUS registration flow.
///
/// Run: cargo run --example basic_integration -p hus-sdk
use ark_bn254::Fr;
use ark_ff::{BigInteger, PrimeField};
use ark_serialize::CanonicalSerialize;
use hus_sdk::crypto::PoseidonConstants;
use hus_sdk::liveness::create_standard_session;
use hus_sdk::prover::{create_uniqueness_proof, generate_parameters};
use hus_sdk::{require_liveness, HusClient, RAW_DIM, PROJ_DIM};

fn make_projection_matrix(seed: &[u8; 32]) -> [[f32; RAW_DIM]; PROJ_DIM] {
    let mut matrix = [[0.0f32; RAW_DIM]; PROJ_DIM];
    for i in 0..PROJ_DIM {
        for j in 0..RAW_DIM {
            let val = ((i * j) as f32) % 100.0 / 100.0;
            let mix = seed[(i + j) % 32] as f32 / 255.0;
            matrix[i][j] = (val + mix) / 2.0;
        }
    }
    matrix
}

fn format_hex(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(bytes.len() * 2 + 2);
    s.push_str("0x");
    for b in bytes {
        s.push_str(&format!("{:02x}", b));
    }
    s
}

/// Convert an `Fr` to `[u8; 32]` LE bytes (reverse of `Fr::from_le_bytes_mod_order`).
fn fr_to_bytes(f: Fr) -> [u8; 32] {
    let bigint = f.into_bigint();
    let le = bigint.to_bytes_le();
    let mut out = [0u8; 32];
    let n = le.len().min(32);
    out[..n].copy_from_slice(&le[..n]);
    out
}

fn main() {
    println!("=== HUS Production Integration Example ===\n");

    let seed: [u8; 32] = [
        14, 99, 214, 88, 45, 112, 9, 201, 33, 47, 88, 192, 5, 66, 12, 90,
        81, 4, 11, 76, 54, 98, 23, 190, 44, 3, 89, 101, 220, 11, 5, 74,
    ];
    println!("[1] Seed retrieved: {}", format_hex(&seed));

    let (pk, vk) = generate_parameters();
    let mut vk_bytes = Vec::new();
    CanonicalSerialize::serialize_uncompressed(&vk, &mut vk_bytes).unwrap();
    println!("[2] Proving key + verifying key generated (vk: {} bytes)", vk_bytes.len());

    let matrix = make_projection_matrix(&seed);
    println!("[3] Projection matrix: {}x{}", PROJ_DIM, RAW_DIM);

    let client = HusClient::new("app_alpha_dao_2026".into(), matrix);
    println!("[4] Client initialized for app: {}", client.app_id);

    let mut liveness_session = create_standard_session(&seed);
    println!("[5] Liveness session: {} challenges", liveness_session.challenge_count());
    for i in 0..liveness_session.challenge_count() {
        liveness_session.verify_response(i).expect("verify failed");
    }
    let liveness_result = liveness_session.finalize();
    println!(
        "     Score: {}/100 (min 60) — {}",
        liveness_result.score,
        if liveness_result.passed { "PASSED" } else { "FAILED" }
    );
    require_liveness(&liveness_result).expect("liveness check failed");

    let raw_biometric: [f32; RAW_DIM] = [0.0112; RAW_DIM];
    println!("[6] Raw biometric: {} floats", raw_biometric.len());

    let isolated = client.apply_matrix_isolation(&raw_biometric);
    println!("[7] Obfuscated vector: {} projected features", isolated.len());

    // The preimage witnesses known only to the user, hidden inside the proof.
    let constants = PoseidonConstants::new();
    let preimage = [Fr::from(42u64), Fr::from(123u64)];
    let comm_fr = constants.sponge_native(&preimage);
    let commitment = fr_to_bytes(comm_fr);
    println!("[8] Commitment (Poseidon(preimage)): {}", format_hex(&commitment));

    let proof = create_uniqueness_proof(&pk, &preimage, comm_fr);
    println!("[9] Groth16 proof: {} bytes", proof.len());

    let self_distance = HusClient::euclidean_distance(&isolated, &isolated);
    println!("[10] Self-distance: {:.6}", self_distance);

    let threshold: f32 = 1.0;
    let mut contract = hus_contract::HusContract::new(threshold);
    contract
        .onboard_app("app_alpha_dao_2026".into(), [0u8; 32], seed, vk_bytes)
        .expect("onboard failed");
    println!("[11] App onboarded with VK");

    let result = contract
        .verify_uniqueness("app_alpha_dao_2026", &proof, commitment, self_distance)
        .expect("verification failed");

    println!("\n=== Verification Result ===");
    println!("  Unique:              {}", result.is_unique);
    println!("  Score:               {}", result.uniqueness_score);
    println!("  Registry updated:    {}", result.registry_updated);

    let dup_result = contract
        .verify_uniqueness("app_alpha_dao_2026", &proof, commitment, self_distance)
        .expect("duplicate check failed");

    println!("\n=== Duplicate Attempt ===");
    println!("  Unique:              {}", dup_result.is_unique);
    println!("  Registry updated:    {}", dup_result.registry_updated);
    println!("  (Expected: false, false)\n");

    println!("=== Example Complete ===");
}
