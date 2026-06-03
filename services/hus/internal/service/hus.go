package service

import (
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"math"
	"sync"
	"time"
)

const (
	defaultRawDim = 512
	defaultProjDim = 128
	defaultThreshold = 1.0
	minUniquenessScore = 80
)

var (
	ErrAppNotFound        = errors.New("app not found")
	ErrAppAlreadyExists   = errors.New("app already registered")
	ErrInvalidProof       = errors.New("invalid ZK proof")
	ErrDuplicateCommitment = errors.New("duplicate commitment")
	ErrNoVerification     = errors.New("no verification found")
)

type AppRegistry struct {
	AppID          string
	OwnerPubkey    [32]byte
	MatrixSeed     [32]byte
	BiometricHashes [][32]byte
	VerificationKey []byte
}

type VerificationResult struct {
	UniquenessScore uint8
	IsUnique        bool
	RegistryUpdated bool
}

type HUSService struct {
	mu                 sync.RWMutex
	appDirectory       map[string]*AppRegistry
	verificationScores map[string]float64
	calibration        float64
}

func NewHUSService() *HUSService {
	return &HUSService{
		appDirectory:       make(map[string]*AppRegistry),
		verificationScores: make(map[string]float64),
		calibration:        defaultThreshold,
	}
}

func (s *HUSService) OnboardApp(appID string, owner [32]byte, seed [32]byte, vkBytes []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.appDirectory[appID]; exists {
		return ErrAppAlreadyExists
	}

	s.appDirectory[appID] = &AppRegistry{
		AppID:          appID,
		OwnerPubkey:    owner,
		MatrixSeed:     seed,
		BiometricHashes: make([][32]byte, 0),
		VerificationKey: vkBytes,
	}
	return nil
}

func (s *HUSService) VerifyUniqueness(appID string, commitment [32]byte, distance float64) (*VerificationResult, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	registry, exists := s.appDirectory[appID]
	if !exists {
		return nil, ErrAppNotFound
	}

	score := calculateScore(distance, s.calibration)

	for _, existing := range registry.BiometricHashes {
		if existing == commitment {
			return &VerificationResult{
				UniquenessScore: score,
				IsUnique:        false,
				RegistryUpdated: false,
			}, nil
		}
	}

	if len(registry.BiometricHashes) > 0 && score >= minUniquenessScore {
		return &VerificationResult{
			UniquenessScore: score,
			IsUnique:        false,
			RegistryUpdated: false,
		}, nil
	}

	registry.BiometricHashes = append(registry.BiometricHashes, commitment)
	s.verificationScores[string(commitment[:])] = float64(score)

	return &VerificationResult{
		UniquenessScore: score,
		IsUnique:        true,
		RegistryUpdated: true,
	}, nil
}

func calculateScore(distance, threshold float64) uint8 {
	if threshold <= 0 {
		return 0
	}
	raw := (1.0 - distance/threshold) * 100.0
	clamped := math.Max(0, math.Min(100, raw))
	return uint8(clamped)
}

func (s *HUSService) GetMatrixSeed(appID string) ([32]byte, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	registry, exists := s.appDirectory[appID]
	if !exists {
		return [32]byte{}, ErrAppNotFound
	}
	return registry.MatrixSeed, nil
}

func (s *HUSService) GetVerificationStatus(identityID string) (*VerificationResult, float64, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	score, exists := s.verificationScores[identityID]
	if !exists {
		return nil, 0, ErrNoVerification
	}

	return &VerificationResult{
		UniquenessScore: uint8(score),
		IsUnique:        score >= minUniquenessScore,
	}, score, nil
}

func Commitment(data []byte) [32]byte {
	return sha256.Sum256(data)
}

func GenerateMatrixSeed(appID string) [32]byte {
	hash := sha256.Sum256([]byte(appID + time.Now().String()))
	return hash
}

func Float32ToBytes(f float32) [32]byte {
	var buf [32]byte
	bits := math.Float32bits(f)
	binary.LittleEndian.PutUint32(buf[:4], bits)
	return buf
}
