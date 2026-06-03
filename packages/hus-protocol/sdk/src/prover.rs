use alloc::vec;
use alloc::vec::Vec;
use ark_bn254::{Bn254, Fr};
use ark_ff::AdditiveGroup;
use ark_groth16::r1cs_to_qap::LibsnarkReduction;
use ark_groth16::{Groth16, ProvingKey, VerifyingKey};
use ark_relations::r1cs::{ConstraintSynthesizer, ConstraintSystemRef, SynthesisError};
use ark_r1cs_std::{
    alloc::AllocVar,
    eq::EqGadget,
    fields::fp::FpVar,
    fields::FieldVar,
};
use ark_serialize::{CanonicalDeserialize, CanonicalSerialize};
use ark_std::rand::SeedableRng;

use crate::crypto::{PoseidonConstants, RATE, T};

const HALF_FULL_ROUNDS: usize = 4;
const PARTIAL_ROUNDS: usize = 57;

#[derive(Clone)]
pub struct UniquenessCircuit {
    pub preimage: Vec<Fr>,
    pub commitment: Fr,
}

impl ConstraintSynthesizer<Fr> for UniquenessCircuit {
    fn generate_constraints(self, cs: ConstraintSystemRef<Fr>) -> Result<(), SynthesisError> {
        let comm = FpVar::new_input(cs.clone(), || Ok(self.commitment))?;

        let mut pre = Vec::with_capacity(self.preimage.len());
        for v in &self.preimage {
            pre.push(FpVar::new_witness(cs.clone(), || Ok(*v))?);
        }

        let computed = poseidon_sponge_gadget(cs.clone(), &pre)?;
        computed.enforce_equal(&comm)?;

        Ok(())
    }
}

fn poseidon_sponge_gadget(
    cs: ConstraintSystemRef<Fr>,
    inputs: &[FpVar<Fr>],
) -> Result<FpVar<Fr>, SynthesisError> {
    let constants = PoseidonConstants::new();
    let rc_vars: Vec<FpVar<Fr>> = constants
        .round_constants
        .iter()
        .map(|c| FpVar::new_constant(cs.clone(), *c))
        .collect::<Result<Vec<_>, _>>()?;

    let mut state = [
        FpVar::new_constant(cs.clone(), Fr::ZERO)?,
        FpVar::new_constant(cs.clone(), Fr::ZERO)?,
        FpVar::new_constant(cs.clone(), Fr::ZERO)?,
    ];

    for chunk in inputs.chunks(RATE) {
        for i in 0..chunk.len() {
            state[i] = &state[i] + &chunk[i];
        }
        permute_gadget(cs.clone(), &mut state, &rc_vars, &constants.mds)?;
    }

    Ok(state[0].clone())
}

fn permute_gadget(
    _cs: ConstraintSystemRef<Fr>,
    state: &mut [FpVar<Fr>; T],
    rc: &[FpVar<Fr>],
    mds: &[[Fr; T]; T],
) -> Result<(), SynthesisError> {
    let mut idx = 0;

    for _ in 0..HALF_FULL_ROUNDS {
        for s in state.iter_mut() {
            *s = &*s + &rc[idx];
            idx += 1;
        }
        for s in state.iter_mut() {
            *s = pow5_gadget(s.clone())?;
        }
        mix_gadget(state, mds);
    }

    for _ in 0..PARTIAL_ROUNDS {
        for s in state.iter_mut() {
            *s = &*s + &rc[idx];
            idx += 1;
        }
        state[0] = pow5_gadget(state[0].clone())?;
        mix_gadget(state, mds);
    }

    for _ in 0..HALF_FULL_ROUNDS {
        for s in state.iter_mut() {
            *s = &*s + &rc[idx];
            idx += 1;
        }
        for s in state.iter_mut() {
            *s = pow5_gadget(s.clone())?;
        }
        mix_gadget(state, mds);
    }

    Ok(())
}

fn pow5_gadget(x: FpVar<Fr>) -> Result<FpVar<Fr>, SynthesisError> {
    let x2 = FieldVar::square(&x)?;
    let x4 = FieldVar::square(&x2)?;
    Ok(x4 * x)
}

fn mix_gadget(state: &mut [FpVar<Fr>; T], mds: &[[Fr; T]; T]) {
    let s0 = state[0].clone();
    let s1 = state[1].clone();
    let s2 = state[2].clone();

    let t00 = &s0 * mds[0][0];
    let t01 = &s1 * mds[0][1];
    let t02 = &s2 * mds[0][2];
    state[0] = &t00 + &(&t01 + &t02);

    let t10 = &s0 * mds[1][0];
    let t11 = &s1 * mds[1][1];
    let t12 = &s2 * mds[1][2];
    state[1] = &t10 + &(&t11 + &t12);

    let t20 = &s0 * mds[2][0];
    let t21 = &s1 * mds[2][1];
    let t22 = &s2 * mds[2][2];
    state[2] = &t20 + &(&t21 + &t22);
}

#[cfg(feature = "std")]
fn entropy_seed() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos() as u64)
        .unwrap_or(0)
}

pub fn generate_parameters() -> (ProvingKey<Bn254>, VerifyingKey<Bn254>) {
    let circuit = UniquenessCircuit {
        preimage: vec![Fr::ZERO; 2],
        commitment: Fr::ZERO,
    };
    #[cfg(not(feature = "std"))]
    let seed = 0u64;
    #[cfg(feature = "std")]
    let seed = entropy_seed();
    let mut rng = ark_std::rand::rngs::StdRng::seed_from_u64(seed);
    let pk = Groth16::<Bn254, LibsnarkReduction>::generate_random_parameters_with_reduction(
        circuit,
        &mut rng,
    )
    .unwrap();
    let vk = pk.vk.clone();
    (pk, vk)
}

pub fn create_uniqueness_proof(
    pk: &ProvingKey<Bn254>,
    preimage: &[Fr],
    commitment: Fr,
) -> Vec<u8> {
    let circuit = UniquenessCircuit {
        preimage: preimage.to_vec(),
        commitment,
    };
    #[cfg(not(feature = "std"))]
    let seed = 0u64;
    #[cfg(feature = "std")]
    let seed = entropy_seed();
    let mut rng = ark_std::rand::rngs::StdRng::seed_from_u64(seed);
    let proof =
        Groth16::<Bn254, LibsnarkReduction>::create_random_proof_with_reduction(circuit, pk, &mut rng)
            .unwrap();
    let mut bytes = Vec::new();
    proof.serialize_uncompressed(&mut bytes).unwrap();
    bytes
}

pub fn verify_uniqueness_proof(
    vk: &VerifyingKey<Bn254>,
    proof_bytes: &[u8],
    commitment: Fr,
) -> bool {
    let proof = match ark_groth16::Proof::<Bn254>::deserialize_uncompressed(proof_bytes) {
        Ok(p) => p,
        Err(_) => return false,
    };
    let pvk = ark_groth16::prepare_verifying_key(vk);
    Groth16::<Bn254, LibsnarkReduction>::verify_proof(&pvk, &proof, &[commitment])
        .unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn circuit_satisfiable() {
        let v1 = Fr::from(42u64);
        let v2 = Fr::from(123u64);
        let (pk, vk) = generate_parameters();

        let inputs = [v1, v2];
        let constants = PoseidonConstants::new();
        let commitment = constants.sponge_native(&inputs);

        let proof_bytes = create_uniqueness_proof(&pk, &inputs, commitment);
        assert!(!proof_bytes.is_empty());

        let valid = verify_uniqueness_proof(&vk, &proof_bytes, commitment);
        assert!(valid, "proof should verify");
    }

    #[test]
    fn invalid_proof_rejected() {
        let (_, vk) = generate_parameters();
        let bad_proof = vec![0u8; 128];
        let commitment = Fr::from(99u64);
        let valid = verify_uniqueness_proof(&vk, &bad_proof, commitment);
        assert!(!valid, "invalid proof must be rejected");
    }

    #[test]
    fn wrong_commitment_rejected() {
        let v1 = Fr::from(1u64);
        let v2 = Fr::from(2u64);
        let (pk, vk) = generate_parameters();

        let inputs = [v1, v2];
        let constants = PoseidonConstants::new();
        let real_commitment = constants.sponge_native(&inputs);
        let wrong_commitment = constants.sponge_native(&[Fr::from(99u64), Fr::from(100u64)]);

        let proof_bytes = create_uniqueness_proof(&pk, &inputs, real_commitment);
        let valid = verify_uniqueness_proof(&vk, &proof_bytes, wrong_commitment);
        assert!(!valid, "wrong commitment must be rejected");
    }
}
