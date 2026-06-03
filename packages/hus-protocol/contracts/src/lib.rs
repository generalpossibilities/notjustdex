#![cfg_attr(not(feature = "std"), no_std)]
#![deny(unsafe_code)]

extern crate alloc;

#[cfg(feature = "std")]
extern crate std;

#[cfg(not(feature = "std"))]
#[allow(unsafe_code, static_mut_refs)]
mod wasm_compat {
    use core::alloc::{GlobalAlloc, Layout};
    use core::panic::PanicInfo;

    #[repr(C, align(64))]
    struct Heap([u8; 1024 * 128]);

    static mut HEAP: Heap = Heap([0; 1024 * 128]);
    static mut HEAP_POS: usize = 0;

    pub struct BumpAlloc;

    unsafe impl GlobalAlloc for BumpAlloc {
        unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
            let align = layout.align().max(1);
            let size = layout.size().max(1);
            let pos = HEAP_POS;
            let aligned = (pos + align - 1) & !(align - 1);
            if aligned + size > HEAP.0.len() {
                return core::ptr::null_mut();
            }
            HEAP_POS = aligned + size;
            HEAP.0.as_mut_ptr().add(aligned)
        }
        unsafe fn dealloc(&self, _ptr: *mut u8, _layout: Layout) {}
    }

    #[global_allocator]
    static ALLOC: BumpAlloc = BumpAlloc;

    #[panic_handler]
    fn panic(_info: &PanicInfo) -> ! {
        loop {}
    }
}

use alloc::collections::BTreeMap;
use alloc::string::String;
use alloc::vec::Vec;
use core::fmt;
use serde::{Deserialize, Serialize};

use ark_bn254::{Bn254, Fr};
use ark_ff::PrimeField;
use ark_groth16::r1cs_to_qap::LibsnarkReduction;
use ark_groth16::{Groth16, Proof, VerifyingKey};
use ark_serialize::CanonicalDeserialize;

#[derive(Debug, Clone, PartialEq)]
pub enum ContractError {
    AppNotFound,
    AppAlreadyRegistered,
    InvalidProof,
    DuplicateCommitment,
    DivisionByZero,
}

impl fmt::Display for ContractError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ContractError::AppNotFound => write!(f, "app not found"),
            ContractError::AppAlreadyRegistered => write!(f, "app already registered"),
            ContractError::InvalidProof => write!(f, "invalid ZK proof"),
            ContractError::DuplicateCommitment => write!(f, "duplicate commitment"),
            ContractError::DivisionByZero => write!(f, "division by zero in scoring"),
        }
    }
}

#[cfg(feature = "std")]
impl std::error::Error for ContractError {}

#[derive(Clone, Serialize, Deserialize, Debug, PartialEq)]
pub struct AppRegistry {
    pub app_id: String,
    pub owner_pubkey: [u8; 32],
    pub matrix_seed: [u8; 32],
    pub biometric_hashes: Vec<[u8; 32]>,
    pub verification_key: Vec<u8>,
}

#[derive(Serialize, Deserialize, Debug, PartialEq)]
pub struct VerificationResult {
    pub uniqueness_score: u8,
    pub is_unique: bool,
    pub registry_updated: bool,
}

pub struct HusContract {
    pub app_directory: BTreeMap<String, AppRegistry>,
    pub calibration_threshold: f32,
}

impl HusContract {
    pub fn new(threshold: f32) -> Self {
        Self {
            app_directory: BTreeMap::new(),
            calibration_threshold: threshold,
        }
    }

    pub fn onboard_app(
        &mut self,
        app_id: String,
        owner: [u8; 32],
        seed: [u8; 32],
        vk_bytes: Vec<u8>,
    ) -> Result<(), ContractError> {
        if self.app_directory.contains_key(&app_id) {
            return Err(ContractError::AppAlreadyRegistered);
        }
        self.app_directory.insert(
            app_id.clone(),
            AppRegistry {
                app_id,
                owner_pubkey: owner,
                matrix_seed: seed,
                biometric_hashes: Vec::new(),
                verification_key: vk_bytes,
            },
        );
        Ok(())
    }

    pub fn verify_uniqueness(
        &mut self,
        app_id: &str,
        proof_bytes: &[u8],
        commitment: [u8; 32],
        distance: f32,
    ) -> Result<VerificationResult, ContractError> {
        let registry = self
            .app_directory
            .get_mut(app_id)
            .ok_or(ContractError::AppNotFound)?;

        let vk = match VerifyingKey::<Bn254>::deserialize_uncompressed(&*registry.verification_key)
        {
            Ok(k) => k,
            Err(_) => return Err(ContractError::InvalidProof),
        };
        let proof = match Proof::<Bn254>::deserialize_uncompressed(proof_bytes) {
            Ok(p) => p,
            Err(_) => return Err(ContractError::InvalidProof),
        };

        let comm_fr = Fr::from_le_bytes_mod_order(&commitment);
        let pvk = ark_groth16::prepare_verifying_key(&vk);
        let verified =
            Groth16::<Bn254, LibsnarkReduction>::verify_proof(&pvk, &proof, &[comm_fr])
                .unwrap_or(false);

        if !verified {
            return Err(ContractError::InvalidProof);
        }

        let score = Self::calculate_score(distance, self.calibration_threshold);

        // Duplicate commitment check (always applies).
        if registry.biometric_hashes.contains(&commitment) {
            return Ok(VerificationResult {
                uniqueness_score: score,
                is_unique: false,
                registry_updated: false,
            });
        }

        // Score gate: if there ARE existing registrations and the biometric is too
        // similar (score >= 80), reject as a likely same-person retry.
        if !registry.biometric_hashes.is_empty() && score >= 80 {
            return Ok(VerificationResult {
                uniqueness_score: score,
                is_unique: false,
                registry_updated: false,
            });
        }

        registry.biometric_hashes.push(commitment);
        Ok(VerificationResult {
            uniqueness_score: score,
            is_unique: true,
            registry_updated: true,
        })
    }

    pub fn calculate_score(distance: f32, threshold: f32) -> u8 {
        if threshold <= 0.0 {
            return 0;
        }
        let raw = (1.0 - distance / threshold) * 100.0;
        raw.clamp(0.0, 100.0) as u8
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ark_ff::AdditiveGroup;
    use ark_groth16::ProvingKey;
    use ark_relations::r1cs::{ConstraintSynthesizer, ConstraintSystemRef, SynthesisError};
    use ark_r1cs_std::{
        alloc::AllocVar,
        eq::EqGadget,
        fields::fp::FpVar,
    };
    use ark_serialize::CanonicalSerialize;

    struct DummyCircuit {
        preimage: Vec<Fr>,
        commitment: Fr,
    }

    impl ConstraintSynthesizer<Fr> for DummyCircuit {
        fn generate_constraints(self, cs: ConstraintSystemRef<Fr>) -> Result<(), SynthesisError> {
            let comm = FpVar::new_input(cs.clone(), || Ok(self.commitment))?;
            let mut pre = Vec::with_capacity(self.preimage.len());
            for v in &self.preimage {
                pre.push(FpVar::new_witness(cs.clone(), || Ok(*v))?);
            }
            let mut state = [
                FpVar::new_constant(cs.clone(), Fr::ZERO)?,
                FpVar::new_constant(cs.clone(), Fr::ZERO)?,
                FpVar::new_constant(cs.clone(), Fr::ZERO)?,
            ];
            for chunk in pre.chunks(2) {
                for i in 0..chunk.len() {
                    state[i] = &state[i] + &chunk[i];
                }
            }
            comm.enforce_equal(&state[0])?;
            Ok(())
        }
    }

    fn generate_test_vk() -> (Vec<u8>, ProvingKey<Bn254>) {
        use ark_std::rand::SeedableRng;
        let circuit = DummyCircuit {
            preimage: vec![Fr::ZERO; 2],
            commitment: Fr::ZERO,
        };
        let mut rng = ark_std::rand::rngs::StdRng::seed_from_u64(0xDEAD);
        let pk = Groth16::<Bn254, LibsnarkReduction>::generate_random_parameters_with_reduction(
            circuit, &mut rng,
        )
        .unwrap();
        let mut vk_bytes = Vec::new();
        pk.vk.serialize_uncompressed(&mut vk_bytes).unwrap();
        (vk_bytes, pk)
    }

    fn make_valid_proof(pk: &ProvingKey<Bn254>, comm_bytes: [u8; 32]) -> Vec<u8> {
        use ark_std::rand::SeedableRng;
        let comm_fr = Fr::from_le_bytes_mod_order(&comm_bytes);
        let circuit = DummyCircuit {
            preimage: vec![comm_fr, Fr::ZERO],
            commitment: comm_fr,
        };
        let mut rng = ark_std::rand::rngs::StdRng::seed_from_u64(0xCAFE);
        let proof = Groth16::<Bn254, LibsnarkReduction>::create_random_proof_with_reduction(
            circuit, pk, &mut rng,
        )
        .unwrap();
        let mut bytes = Vec::new();
        proof.serialize_uncompressed(&mut bytes).unwrap();
        bytes
    }

    #[test]
    fn onboard_app_ok() {
        let (vk_bytes, _) = generate_test_vk();
        let mut engine = HusContract::new(1.0);
        let r = engine.onboard_app("a".into(), [0; 32], [1; 32], vk_bytes);
        assert_eq!(r, Ok(()));
    }

    #[test]
    fn onboard_app_duplicate_rejected() {
        let (vk_bytes, _) = generate_test_vk();
        let mut engine = HusContract::new(1.0);
        engine.onboard_app("a".into(), [0; 32], [1; 32], vk_bytes.clone()).unwrap();
        let r = engine.onboard_app("a".into(), [0; 32], [1; 32], vk_bytes);
        assert_eq!(r, Err(ContractError::AppAlreadyRegistered));
    }

    #[test]
    fn app_not_found() {
        let mut engine = HusContract::new(1.0);
        let r = engine.verify_uniqueness("nonexistent", &[], [0; 32], 0.0);
        assert_eq!(r, Err(ContractError::AppNotFound));
    }

    #[test]
    fn invalid_proof_rejected() {
        let (vk_bytes, _) = generate_test_vk();
        let mut engine = HusContract::new(1.0);
        engine.onboard_app("a".into(), [0; 32], [1; 32], vk_bytes).unwrap();
        let bad_proof = vec![0u8; 32];
        let r = engine.verify_uniqueness("a", &bad_proof, [0; 32], 0.0);
        assert_eq!(r, Err(ContractError::InvalidProof));
    }

    #[test]
    fn score_calculation() {
        assert_eq!(HusContract::calculate_score(0.0, 1.0), 100);
        assert_eq!(HusContract::calculate_score(0.5, 1.0), 50);
        assert_eq!(HusContract::calculate_score(1.0, 1.0), 0);
        assert_eq!(HusContract::calculate_score(2.0, 1.0), 0);
    }

    #[test]
    fn score_above_80_rejected() {
        let (vk_bytes, pk) = generate_test_vk();
        let mut engine = HusContract::new(1.0);
        engine.onboard_app("a".into(), [0; 32], [1; 32], vk_bytes).unwrap();
        // First registration with distance large enough to pass.
        let p1 = make_valid_proof(&pk, [1; 32]);
        engine.verify_uniqueness("a", &p1, [1; 32], 0.5).unwrap();
        // Second attempt with distance 0.1 → score 90 ≥ 80 → rejected.
        let p2 = make_valid_proof(&pk, [2; 32]);
        let r = engine.verify_uniqueness("a", &p2, [2; 32], 0.1);
        assert!(r.is_ok());
        let result = r.unwrap();
        assert_eq!(result.uniqueness_score, 90);
        assert!(!result.is_unique);
        assert!(!result.registry_updated);
    }

    #[test]
    fn duplicate_commitment_rejected() {
        let (vk_bytes, pk) = generate_test_vk();
        let mut engine = HusContract::new(1.0);
        engine.onboard_app("a".into(), [0; 32], [1; 32], vk_bytes).unwrap();
        let proof_bytes = make_valid_proof(&pk, [42; 32]);
        let commitment = [42; 32];
        let r1 = engine.verify_uniqueness("a", &proof_bytes, commitment, 0.5);
        assert!(r1.unwrap().is_unique);
        let r2 = engine.verify_uniqueness("a", &proof_bytes, commitment, 0.5);
        assert!(!r2.unwrap().is_unique);
    }

    #[test]
    fn successful_registration_updates_registry() {
        let (vk_bytes, pk) = generate_test_vk();
        let mut engine = HusContract::new(1.0);
        engine.onboard_app("a".into(), [0; 32], [1; 32], vk_bytes).unwrap();
        let proof_bytes = make_valid_proof(&pk, [99; 32]);
        let result = engine.verify_uniqueness("a", &proof_bytes, [99; 32], 0.3).unwrap();
        assert!(result.is_unique);
        assert!(result.registry_updated);
        assert_eq!(result.uniqueness_score, 70);
        assert_eq!(engine.app_directory["a"].biometric_hashes.len(), 1);
    }

    #[test]
    fn error_display() {
        assert_eq!(format!("{}", ContractError::AppNotFound), "app not found");
        assert_eq!(format!("{}", ContractError::AppAlreadyRegistered), "app already registered");
        assert_eq!(format!("{}", ContractError::InvalidProof), "invalid ZK proof");
    }
}
