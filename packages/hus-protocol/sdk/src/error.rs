use core::fmt;

#[derive(Debug, Clone, PartialEq)]
pub enum SdkError {
    MatrixDimensionMismatch { expected: usize, got: usize },
    VectorDimensionMismatch { expected: usize, got: usize },
    InvalidSeed,
    CryptoError { reason: &'static str },
}

impl fmt::Display for SdkError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            SdkError::MatrixDimensionMismatch { expected, got } => {
                write!(f, "matrix dimension mismatch: expected {expected}, got {got}")
            }
            SdkError::VectorDimensionMismatch { expected, got } => {
                write!(f, "vector dimension mismatch: expected {expected}, got {got}")
            }
            SdkError::InvalidSeed => write!(f, "invalid projection seed"),
            SdkError::CryptoError { reason } => write!(f, "crypto error: {reason}"),
        }
    }
}

#[cfg(feature = "std")]
impl std::error::Error for SdkError {}
