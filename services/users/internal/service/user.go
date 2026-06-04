package service

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/dexchats/lib/go/chain"
)

type UserService struct {
	mu       sync.RWMutex
	users    map[string]*UserProfile
	wallets  map[string]*WalletData
	chainCli *chain.Client
	useChain bool
}

type UserProfile struct {
	ID            string    `json:"id"`
	Username      string    `json:"username"`
	DisplayName   string    `json:"display_name"`
	Bio           string    `json:"bio"`
	AvatarURL     string    `json:"avatar_url"`
	PhoneNumber   string    `json:"phone_number"`
	CreatedAt     time.Time `json:"created_at"`
	WalletAddress string    `json:"wallet_address"`
}

type WalletData struct {
	Address      string            `json:"address"`
	IdentityID   string            `json:"identity_id"`
	PublicKey    string            `json:"public_key"`
	PrivateKey   string            `json:"-"` // never serialized
	SeedVersion  int               `json:"seed_version"`
	SeedRotated  bool              `json:"seed_rotated"`
	IsRecovering bool              `json:"is_recovering"`
	Balances     map[string]uint64 `json:"balances"` // VMSHELL nanotokens
}

func NewUserService(graphqlURL string) *UserService {
	svc := &UserService{
		users:   make(map[string]*UserProfile),
		wallets: make(map[string]*WalletData),
	}

	if graphqlURL != "" {
		svc.chainCli = chain.NewClient(graphqlURL)
		svc.useChain = true
		log.Printf("connected to Acki Nacki chain at %s", graphqlURL)
	} else {
		log.Println("no chain GraphQL URL provided — running in offline mode")
	}

	return svc
}

func (s *UserService) CreateUser(phoneNumber, username, displayName string) (*UserProfile, *WalletData, error) {
	if len(username) < 4 {
		return nil, nil, errors.New("username must be at least 4 characters")
	}
	if displayName != "" && len(displayName) < 4 {
		return nil, nil, errors.New("display name must be at least 4 characters")
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	for _, u := range s.users {
		if u.Username == username {
			return nil, nil, errors.New("username already taken")
		}
	}

	id := generateUserID()

	// Generate Ed25519 key pair for Acki Nacki wallet
	keys, err := chain.GenerateKeys()
	if err != nil {
		return nil, nil, fmt.Errorf("generate wallet key: %w", err)
	}

	user := &UserProfile{
		ID:            id,
		Username:      username,
		DisplayName:   displayName,
		PhoneNumber:   phoneNumber,
		CreatedAt:     time.Now(),
		WalletAddress: keys.Address,
	}
	s.users[id] = user

	wallet := &WalletData{
		Address:    keys.Address,
		IdentityID: id,
		PublicKey:  hex.EncodeToString(keys.PublicKey),
		PrivateKey: hex.EncodeToString(keys.PrivateKey),
		Balances:   map[string]uint64{"VMSHELL": 0},
	}
	s.wallets[id] = wallet

	// Register identity on chain (best-effort)
	if s.useChain {
		go func() {
			ctx, cancel := withTimeout(30 * time.Second)
			defer cancel()

			txHash, err := s.chainCli.RegisterIdentity(ctx, keys, username)
			if err != nil {
				log.Printf("on-chain registration for %s: %v", username, err)
				return
			}
			log.Printf("identity registered on chain — tx: %s", txHash)
		}()
	} else {
		log.Printf("user %s created (offline mode — no chain registration)", username)
	}

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

func (s *UserService) GetWallet(identityID string) (*WalletData, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	wallet, exists := s.wallets[identityID]
	if !exists {
		return nil, errors.New("wallet not found")
	}

	// Fetch live VMSHELL balance from chain if connected
	if s.useChain {
		ctx, cancel := withTimeout(10 * time.Second)
		defer cancel()

		bal, err := s.chainCli.GetBalance(ctx, wallet.Address)
		if err == nil {
			wallet.Balances["VMSHELL"] = bal
		} else {
			log.Printf("fetch balance for %s: %v", wallet.Address, err)
		}
	}

	walletCopy := *wallet
	walletCopy.PrivateKey = "" // never expose private key
	return &walletCopy, nil
}

func (s *UserService) GetBalance(identityID string) (uint64, error) {
	wallet, err := s.GetWallet(identityID)
	if err != nil {
		return 0, err
	}
	return wallet.Balances["VMSHELL"], nil
}

func (s *UserService) UpdateProfile(id, displayName, bio, avatarURL string) (*UserProfile, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	user, exists := s.users[id]
	if !exists {
		return nil, errors.New("user not found")
	}

	if displayName != "" {
		if len(displayName) < 4 {
			return nil, errors.New("display name must be at least 4 characters")
		}
		user.DisplayName = displayName
	}
	if bio != "" {
		user.Bio = bio
	}
	if avatarURL != "" {
		user.AvatarURL = avatarURL
	}

	return user, nil
}

func (s *UserService) CheckUsernameAvailability(username string) bool {
	if len(username) < 4 {
		return false
	}

	// Check chain first if connected
	if s.useChain {
		ctx, cancel := withTimeout(10 * time.Second)
		defer cancel()

		available, err := s.chainCli.CheckUsernameAvailability(ctx, username)
		if err == nil && !available {
			return false
		}
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

func (s *UserService) ResolveUsername(username string) (*UserProfile, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, u := range s.users {
		if u.Username == username {
			return u, nil
		}
	}

	if s.useChain {
		ctx, cancel := withTimeout(10 * time.Second)
		defer cancel()

		addr, err := s.chainCli.ResolveUsername(ctx, username)
		if err == nil && addr != "" {
			return &UserProfile{
				ID:            "chain_" + username,
				Username:      username,
				WalletAddress: addr,
			}, nil
		}
	}

	return nil, errors.New("username not found")
}

func (s *UserService) ExportMnemonic(identityID string) ([]string, error) {
	s.mu.RLock()
	wallet, exists := s.wallets[identityID]
	s.mu.RUnlock()

	if !exists {
		return nil, errors.New("wallet not found")
	}

	return chain.GenerateSeedPhrase(), nil
}

func (s *UserService) RotateSeedPhrase(identityID string) ([]string, error) {
	s.mu.Lock()
	wallet, exists := s.wallets[identityID]
	if !exists {
		s.mu.Unlock()
		return nil, errors.New("wallet not found")
	}

	wallet.SeedVersion++
	wallet.SeedRotated = true

	// Generate new key pair
	keys, err := chain.GenerateKeys()
	if err != nil {
		s.mu.Unlock()
		return nil, fmt.Errorf("rotate key: %w", err)
	}

	wallet.Address = keys.Address
	wallet.PublicKey = hex.EncodeToString(keys.PublicKey)
	wallet.PrivateKey = hex.EncodeToString(keys.PrivateKey)

	// Update user's wallet address
	if user, ok := s.users[identityID]; ok {
		user.WalletAddress = keys.Address
	}

	s.mu.Unlock()

	// Update on chain if connected
	if s.useChain {
		ctx, cancel := withTimeout(30 * time.Second)
		defer cancel()

		txHash, err := s.chainCli.RotateSeedPhrase(ctx, keys, nil)
		if err != nil {
			log.Printf("on-chain seed rotation for %s: %v", identityID, err)
		} else {
			log.Printf("seed rotated on chain — tx: %s", txHash)
		}
	}

	return chain.GenerateSeedPhrase(), nil
}

// ─── Internal ───────────────────────────────────────────────────

func generateUserID() string {
	bytes := make([]byte, 16)
	rand.Read(bytes)
	return "usr_" + hex.EncodeToString(bytes)
}

// withTimeout creates a simple context-like timeout.
func withTimeout(d time.Duration) (interface {
	Deadline() (time.Time, bool)
	Done() <-chan struct{}
	Err() error
}, func()) {
	return newTimeout(d)
}

type timeoutCtx struct {
	done chan struct{}
	err  error
}

func newTimeout(d time.Duration) (*timeoutCtx, func()) {
	ctx := &timeoutCtx{done: make(chan struct{})}
	timer := time.AfterFunc(d, func() {
		ctx.err = errors.New("deadline exceeded")
		close(ctx.done)
	})
	return ctx, func() { timer.Stop() }
}

func (c *timeoutCtx) Deadline() (time.Time, bool) {
	return time.Now().Add(time.Second), true
}

func (c *timeoutCtx) Done() <-chan struct{} {
	return c.done
}

func (c *timeoutCtx) Err() error {
	return c.err
}
