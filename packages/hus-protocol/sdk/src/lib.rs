#![cfg_attr(not(feature = "std"), no_std)]
#![deny(unsafe_code)]

extern crate alloc;

#[cfg(feature = "std")]
extern crate std;

pub mod config;
pub mod crypto;
pub mod error;
pub mod liveness;
pub mod prover;

use alloc::string::String;

pub use config::HusConfig;
pub use error::SdkError;
pub use liveness::{LivenessResult, LivenessSession, require_liveness};

pub const RAW_DIM: usize = config::DEFAULT_RAW_DIM;
pub const PROJ_DIM: usize = config::DEFAULT_PROJ_DIM;

pub struct HusClient {
    pub app_id: String,
    pub projection_matrix: [[f32; RAW_DIM]; PROJ_DIM],
}

impl HusClient {
    pub fn new(app_id: String, matrix: [[f32; RAW_DIM]; PROJ_DIM]) -> Self {
        Self {
            app_id,
            projection_matrix: matrix,
        }
    }

    pub fn apply_matrix_isolation(&self, raw: &[f32; RAW_DIM]) -> [f32; PROJ_DIM] {
        let mut result = [0.0f32; PROJ_DIM];
        for (i, r) in result.iter_mut().enumerate().take(PROJ_DIM) {
            let row = &self.projection_matrix[i];
            let mut sum = 0.0f32;
            for (rv, rw) in raw.iter().zip(row.iter()) {
                sum += rv * rw;
            }
            *r = sum;
        }
        result
    }

    pub fn euclidean_distance(a: &[f32; PROJ_DIM], b: &[f32; PROJ_DIM]) -> f32 {
        let mut sum = 0.0f32;
        for i in 0..PROJ_DIM {
            let d = a[i] - b[i];
            sum += d * d;
        }
        libm::sqrtf(sum)
    }

    pub fn process_with_liveness(
        &self,
        session: &LivenessSession,
        raw: &[f32; RAW_DIM],
    ) -> Result<[f32; PROJ_DIM], &'static str> {
        let result = session.finalize();
        require_liveness(&result)?;
        Ok(self.apply_matrix_isolation(raw))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::UNIQUENESS_MIN_SCORE;

    fn mock_matrix() -> [[f32; RAW_DIM]; PROJ_DIM] {
        let mut m = [[0.0f32; RAW_DIM]; PROJ_DIM];
        for (i, row) in m.iter_mut().enumerate().take(PROJ_DIM) {
            for (j, cell) in row.iter_mut().enumerate().take(RAW_DIM) {
                *cell = ((i * j) as f32 % 100.0) / 100.0;
            }
        }
        m
    }

    fn mock_embedding() -> [f32; RAW_DIM] {
        [0.0112; RAW_DIM]
    }

    #[test]
    fn matrix_isolation_produces_correct_dimensions() {
        let client = HusClient::new("test".into(), mock_matrix());
        let result = client.apply_matrix_isolation(&mock_embedding());
        assert_eq!(result.len(), PROJ_DIM);
    }

    #[test]
    fn euclidean_distance_zero() {
        let v = [0.5f32; PROJ_DIM];
        assert_eq!(HusClient::euclidean_distance(&v, &v), 0.0);
    }

    #[test]
    fn euclidean_distance_positive() {
        let a = [0.0f32; PROJ_DIM];
        let b = [3.0f32; PROJ_DIM];
        let d = HusClient::euclidean_distance(&a, &b);
        let expected = ((PROJ_DIM as f32) * 9.0f32).sqrt();
        assert!((d - expected).abs() < 1e-5);
    }

    #[test]
    fn matrix_isolation_deterministic() {
        let client = HusClient::new("test".into(), mock_matrix());
        let e = mock_embedding();
        let a = client.apply_matrix_isolation(&e);
        let b = client.apply_matrix_isolation(&e);
        assert_eq!(a, b);
    }

    #[test]
    fn different_embedding_different_result() {
        let client = HusClient::new("test".into(), mock_matrix());
        let a = client.apply_matrix_isolation(&[0.0; RAW_DIM]);
        let b = client.apply_matrix_isolation(&[1.0; RAW_DIM]);
        assert_ne!(a, b);
    }

    #[test]
    fn default_constants_match_config() {
        assert_eq!(RAW_DIM, config::DEFAULT_RAW_DIM);
        assert_eq!(PROJ_DIM, config::DEFAULT_PROJ_DIM);
        assert_eq!(UNIQUENESS_MIN_SCORE, config::UNIQUENESS_MIN_SCORE);
    }
}
