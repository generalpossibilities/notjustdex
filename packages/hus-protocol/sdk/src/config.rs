pub const DEFAULT_RAW_DIM: usize = 512;
pub const DEFAULT_PROJ_DIM: usize = 128;
pub const DEFAULT_THRESHOLD: f32 = 1.0;
pub const UNIQUENESS_MIN_SCORE: u8 = 80;

#[derive(Debug, Clone)]
pub struct HusConfig {
    pub raw_dim: usize,
    pub proj_dim: usize,
    pub threshold: f32,
    pub uniqueness_min_score: u8,
}

impl HusConfig {
    pub const fn default() -> Self {
        Self {
            raw_dim: DEFAULT_RAW_DIM,
            proj_dim: DEFAULT_PROJ_DIM,
            threshold: DEFAULT_THRESHOLD,
            uniqueness_min_score: UNIQUENESS_MIN_SCORE,
        }
    }

    pub const fn custom(raw_dim: usize, proj_dim: usize, threshold: f32, min_score: u8) -> Self {
        Self {
            raw_dim,
            proj_dim,
            threshold,
            uniqueness_min_score: min_score,
        }
    }
}

impl Default for HusConfig {
    fn default() -> Self {
        Self::default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_config_matches_constants() {
        let cfg = HusConfig::default();
        assert_eq!(cfg.raw_dim, DEFAULT_RAW_DIM);
        assert_eq!(cfg.proj_dim, DEFAULT_PROJ_DIM);
        assert_eq!(cfg.threshold, DEFAULT_THRESHOLD);
        assert_eq!(cfg.uniqueness_min_score, UNIQUENESS_MIN_SCORE);
    }

    #[test]
    fn custom_config() {
        let cfg = HusConfig::custom(256, 64, 2.0, 70);
        assert_eq!(cfg.raw_dim, 256);
        assert_eq!(cfg.proj_dim, 64);
        assert_eq!(cfg.threshold, 2.0);
        assert_eq!(cfg.uniqueness_min_score, 70);
    }
}
