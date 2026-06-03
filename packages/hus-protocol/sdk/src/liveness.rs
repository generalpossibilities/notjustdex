use alloc::vec::Vec;

#[derive(Debug, Clone, PartialEq)]
pub enum LivenessChallenge {
    Blink,
    Smile,
    TurnHead,
    DepthMeasurement,
    ChallengeResponse([u8; 8]),
}

impl LivenessChallenge {
    pub fn description(&self) -> &'static str {
        match self {
            LivenessChallenge::Blink => "blink your eyes",
            LivenessChallenge::Smile => "smile naturally",
            LivenessChallenge::TurnHead => "turn head slightly",
            LivenessChallenge::DepthMeasurement => "hold still for depth scan",
            LivenessChallenge::ChallengeResponse(_) => "respond to random challenge",
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct LivenessResult {
    pub passed: bool,
    pub score: u8,
    pub challenges_passed: usize,
    pub challenges_total: usize,
}

#[derive(Debug, Clone)]
struct ChallengeState {
    #[allow(dead_code)]
    challenge: LivenessChallenge,
    completed: bool,
}

#[derive(Debug, Clone)]
pub struct LivenessSession {
    challenges: Vec<ChallengeState>,
    min_pass_score: u8,
}

impl LivenessSession {
    pub fn new(min_pass_score: u8) -> Self {
        Self {
            challenges: Vec::new(),
            min_pass_score,
        }
    }

    pub fn add_challenge(&mut self, challenge: LivenessChallenge) {
        self.challenges.push(ChallengeState {
            challenge,
            completed: false,
        });
    }

    pub fn challenge_count(&self) -> usize {
        self.challenges.len()
    }

    pub fn verify_response(&mut self, index: usize) -> Result<(), &'static str> {
        if index >= self.challenges.len() {
            return Err("challenge index out of bounds");
        }
        self.challenges[index].completed = true;
        Ok(())
    }

    pub fn challenges_passed(&self) -> usize {
        self.challenges.iter().filter(|c| c.completed).count()
    }

    pub fn finalize(&self) -> LivenessResult {
        let total = self.challenges.len();
        let passed = self.challenges_passed();
        let score = if total == 0 {
            0
        } else {
            ((passed as f32 / total as f32) * 100.0) as u8
        };
        LivenessResult {
            passed: score >= self.min_pass_score,
            score,
            challenges_passed: passed,
            challenges_total: total,
        }
    }
}

pub fn create_standard_session(rng_seed: &[u8]) -> LivenessSession {
    let mut session = LivenessSession::new(60);
    session.add_challenge(LivenessChallenge::Blink);
    session.add_challenge(LivenessChallenge::Smile);
    session.add_challenge(LivenessChallenge::DepthMeasurement);
    let mut cr_bytes = [0u8; 8];
    let len = rng_seed.len().min(8);
    cr_bytes[..len].copy_from_slice(&rng_seed[..len]);
    session.add_challenge(LivenessChallenge::ChallengeResponse(cr_bytes));
    session
}

pub fn require_liveness(result: &LivenessResult) -> Result<(), &'static str> {
    if result.passed {
        Ok(())
    } else {
        Err("liveness check failed: possible spoof attempt")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn session_starts_empty() {
        let s = LivenessSession::new(60);
        assert_eq!(s.challenge_count(), 0);
        assert_eq!(s.challenges_passed(), 0);
    }

    #[test]
    fn verify_all_challenges_passes() {
        let mut s = LivenessSession::new(50);
        s.add_challenge(LivenessChallenge::Blink);
        s.add_challenge(LivenessChallenge::Smile);
        s.verify_response(0).unwrap();
        s.verify_response(1).unwrap();
        let r = s.finalize();
        assert!(r.passed);
        assert_eq!(r.score, 100);
        assert_eq!(r.challenges_passed, 2);
    }

    #[test]
    fn partial_pass_below_threshold_fails() {
        let mut s = LivenessSession::new(80);
        s.add_challenge(LivenessChallenge::Blink);
        s.add_challenge(LivenessChallenge::Smile);
        s.verify_response(0).unwrap();
        let r = s.finalize();
        assert!(!r.passed);
        assert_eq!(r.score, 50);
    }

    #[test]
    fn no_challenges_returns_zero_score() {
        let s = LivenessSession::new(50);
        let r = s.finalize();
        assert!(!r.passed);
        assert_eq!(r.score, 0);
    }

    #[test]
    fn verify_invalid_index_returns_error() {
        let mut s = LivenessSession::new(50);
        s.add_challenge(LivenessChallenge::Blink);
        assert!(s.verify_response(5).is_err());
    }

    #[test]
    fn require_liveness_passed() {
        let r = LivenessResult {
            passed: true,
            score: 100,
            challenges_passed: 3,
            challenges_total: 3,
        };
        assert!(require_liveness(&r).is_ok());
    }

    #[test]
    fn require_liveness_failed() {
        let r = LivenessResult {
            passed: false,
            score: 30,
            challenges_passed: 1,
            challenges_total: 3,
        };
        assert!(require_liveness(&r).is_err());
    }

    #[test]
    fn standard_session_has_four_challenges() {
        let s = create_standard_session(&[0xAB; 32]);
        assert_eq!(s.challenge_count(), 4);
    }

    #[test]
    fn challenge_descriptions_not_empty() {
        for c in &[
            LivenessChallenge::Blink,
            LivenessChallenge::Smile,
            LivenessChallenge::TurnHead,
            LivenessChallenge::DepthMeasurement,
            LivenessChallenge::ChallengeResponse([0; 8]),
        ] {
            assert!(!c.description().is_empty());
        }
    }
}
