package service

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"sync"
	"time"
)

type UserService struct {
	mu      sync.RWMutex
	users   map[string]*UserProfile
	wallets map[string]*Wallet
}

type UserProfile struct {
	ID          string
	Username    string
	DisplayName string
	Bio         string
	AvatarURL   string
	PhoneNumber string
	CreatedAt   time.Time
}

type Wallet struct {
	Address      string
	IdentityID   string
	Balance      map[string]string
	IsRecovering bool
}

func NewUserService() *UserService {
	return &UserService{
		users:   make(map[string]*UserProfile),
		wallets: make(map[string]*Wallet),
	}
}

func (s *UserService) CreateUser(phoneNumber, username, displayName string) (*UserProfile, *Wallet, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if len(username) < 4 {
		return nil, nil, errors.New("username must be at least 4 characters")
	}

	for _, u := range s.users {
		if u.Username == username {
			return nil, nil, errors.New("username already taken on chain")
		}
	}

	id := generateUserID()
	user := &UserProfile{
		ID:          id,
		Username:    username,
		DisplayName: displayName,
		PhoneNumber: phoneNumber,
		CreatedAt:   time.Now(),
	}
	s.users[id] = user

	wallet := &Wallet{
		Address:    username,
		IdentityID: id,
		Balance:    map[string]string{"DEX": "0", "USDC": "0"},
	}
	s.wallets[id] = wallet

	return user, wallet, nil
}

func (s *UserService) GetUser(id string) (*UserProfile, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	user, exists := s.users[id]
	if !exists {
		return nil, errors.New("user not found")
	}
	return user, nil
}

func (s *UserService) GetWallet(identityID string) (*Wallet, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	wallet, exists := s.wallets[identityID]
	if !exists {
		return nil, errors.New("wallet not found")
	}
	return wallet, nil
}

func (s *UserService) GetBalance(identityID, token string) (string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	wallet, exists := s.wallets[identityID]
	if !exists {
		return "", errors.New("wallet not found")
	}
	balance, ok := wallet.Balance[token]
	if !ok {
		return "0", nil
	}
	return balance, nil
}

func (s *UserService) UpdateProfile(id, displayName, bio, avatarURL string) (*UserProfile, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	user, exists := s.users[id]
	if !exists {
		return nil, errors.New("user not found")
	}

	if displayName != "" {
		user.DisplayName = displayName
	}
	user.Bio = bio
	if avatarURL != "" {
		user.AvatarURL = avatarURL
	}

	return user, nil
}

func (s *UserService) CheckUsernameAvailability(username string) bool {
	if len(username) < 4 {
		return false
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, u := range s.users {
		if u.Username == username {
			return false
		}
	}
	return true
}

func (s *UserService) ExportMnemonic(identityID string) ([]string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	_, exists := s.users[identityID]
	if !exists {
		return nil, errors.New("user not found")
	}
	seed := generateSeedPhrase()
	return seed, nil
}

func (s *UserService) RotateSeedPhrase(identityID string) ([]string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	_, exists := s.users[identityID]
	if !exists {
		return nil, errors.New("user not found")
	}
	return generateSeedPhrase(), nil
}

func generateSeedPhrase() []string {
	words := []string{
		"abandon", "ability", "able", "about", "above", "absent",
		"absorb", "abstract", "absurd", "abuse", "access", "accident",
		"account", "accuse", "achieve", "acid", "acoustic", "acquire",
		"across", "act", "action", "actor", "actress", "actual",
	}
	return words
}

func (s *UserService) ResolveUsername(username string) (*UserProfile, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, u := range s.users {
		if u.Username == username {
			return u, nil
		}
	}
	return nil, errors.New("username not found")
}

func generateUserID() string {
	return "user_" + time.Now().Format("20060102150405")
}

func generateAddress() string {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		panic(err)
	}
	return "0x" + hex.EncodeToString(bytes)
}
