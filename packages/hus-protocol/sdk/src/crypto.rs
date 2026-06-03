use alloc::vec::Vec;
use ark_bn254::Fr;
use ark_ff::{AdditiveGroup, Field, PrimeField};

use crate::{PROJ_DIM, RAW_DIM};

pub const RATE: usize = 2;
pub const T: usize = 3;
const HALF_FULL_ROUNDS: usize = 4;
const PARTIAL_ROUNDS: usize = 57;

pub struct PoseidonConstants {
    pub round_constants: Vec<Fr>,
    pub mds: [[Fr; T]; T],
}

impl Default for PoseidonConstants {
    fn default() -> Self {
        Self::new()
    }
}

impl PoseidonConstants {
    pub fn new() -> Self {
        Self {
            round_constants: Self::generate_constants(),
            mds: Self::mds_matrix(),
        }
    }

    fn generate_constants() -> Vec<Fr> {
        let count = (HALF_FULL_ROUNDS * 2 + PARTIAL_ROUNDS) * T;
        let mut c = Vec::with_capacity(count);
        let mut seed = Fr::from(42u64);
        for i in 0..count {
            seed = seed.pow([5u64]) + Fr::from(i as u64);
            c.push(seed);
        }
        c
    }

    fn mds_matrix() -> [[Fr; T]; T] {
        [
            [Fr::from(2u64), Fr::from(1u64), Fr::from(1u64)],
            [Fr::from(1u64), -Fr::from(1u64), Fr::from(1u64)],
            [Fr::from(1u64), Fr::from(1u64), -Fr::from(1u64)],
        ]
    }

    pub fn permute_native(&self, state: &mut [Fr; T]) {
        let mut idx = 0;
        for _ in 0..HALF_FULL_ROUNDS {
            for s in state.iter_mut().take(T) {
                *s += self.round_constants[idx];
                idx += 1;
            }
            for s in state.iter_mut().take(T) {
                *s = s.pow([5u64]);
            }
            self.mix_native(state);
        }
        for _ in 0..PARTIAL_ROUNDS {
            for s in state.iter_mut().take(T) {
                *s += self.round_constants[idx];
                idx += 1;
            }
            state[0] = state[0].pow([5u64]);
            self.mix_native(state);
        }
        for _ in 0..HALF_FULL_ROUNDS {
            for s in state.iter_mut().take(T) {
                *s += self.round_constants[idx];
                idx += 1;
            }
            for s in state.iter_mut().take(T) {
                *s = s.pow([5u64]);
            }
            self.mix_native(state);
        }
    }

    fn mix_native(&self, state: &mut [Fr; T]) {
        let mut result = [Fr::ZERO; T];
        for (i, r) in result.iter_mut().enumerate().take(T) {
            for (j, s) in state.iter().enumerate().take(T) {
                *r += self.mds[i][j] * s;
            }
        }
        *state = result;
    }

    pub fn sponge_native(&self, inputs: &[Fr]) -> Fr {
        let mut state = [Fr::ZERO; T];
        for chunk in inputs.chunks(RATE) {
            for i in 0..chunk.len() {
                state[i] += chunk[i];
            }
            self.permute_native(&mut state);
        }
        state[0]
    }
}

fn bytes_to_fes(data: &[u8]) -> Vec<Fr> {
    let mut elements = Vec::with_capacity(data.len() / 31 + 1);
    for chunk in data.chunks(31) {
        let mut bytes = [0u8; 32];
        bytes[..chunk.len()].copy_from_slice(chunk);
        elements.push(Fr::from_le_bytes_mod_order(&bytes));
    }
    elements
}

fn fe_to_bytes(fe: Fr) -> [u8; 32] {
    let bigint = fe.into_bigint();
    let limbs = bigint.0;
    let mut result = [0u8; 32];
    for i in 0..4 {
        let limb_bytes = limbs[i].to_le_bytes();
        result[i * 8..(i + 1) * 8].copy_from_slice(&limb_bytes);
    }
    result
}

pub fn hash_commitment(data: &[u8]) -> [u8; 32] {
    let constants = PoseidonConstants::new();
    let inputs = bytes_to_fes(data);
    let result = constants.sponge_native(&inputs);
    fe_to_bytes(result)
}

pub fn commit_isolated_vector(vec: &[f32; PROJ_DIM]) -> [u8; 32] {
    let constants = PoseidonConstants::new();
    let mut inputs = Vec::with_capacity(PROJ_DIM);
    for v in vec {
        let bits = v.to_bits();
        inputs.push(Fr::from(bits as u64));
    }
    let result = constants.sponge_native(&inputs);
    fe_to_bytes(result)
}

pub fn build_mock_proof(commitment: &[u8; 32]) -> Vec<u8> {
    let mut proof = Vec::new();
    proof.extend_from_slice(commitment);
    proof.push(0x01);
    proof
}

pub const MOCK_RAW_EMBEDDING: [f32; RAW_DIM] = [0.0112; RAW_DIM];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn commitment_is_32_bytes() {
        let c = hash_commitment(b"hello");
        assert_eq!(c.len(), 32);
    }

    #[test]
    fn commitment_deterministic() {
        let a = hash_commitment(b"test");
        let b = hash_commitment(b"test");
        assert_eq!(a, b);
    }

    #[test]
    fn different_input_different_commitment() {
        let a = hash_commitment(b"alpha");
        let b = hash_commitment(b"beta");
        assert_ne!(a, b);
    }

    #[test]
    fn vector_commitment_is_32_bytes() {
        let v = [0.5f32; PROJ_DIM];
        let c = commit_isolated_vector(&v);
        assert_eq!(c.len(), 32);
    }

    #[test]
    fn mock_proof_contains_commitment() {
        let c = [0xabu8; 32];
        let p = build_mock_proof(&c);
        assert_eq!(&p[..32], &c[..]);
        assert_eq!(p[32], 0x01);
    }

    #[test]
    fn poseidon_output_differs_from_input() {
        let input = hash_commitment(b"input");
        let output = hash_commitment(&input);
        assert_ne!(input, output);
    }
}
