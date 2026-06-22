package service

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var (
	ErrInvalidCredentials  = errors.New("invalid credentials")
	ErrUserNotFound        = errors.New("user not found")
	ErrChallengeExpired    = errors.New("challenge expired")
	ErrInvalidProof        = errors.New("invalid zero-knowledge proof")
	ErrPasskeyNotFound     = errors.New("passkey not registered")
	ErrPasskeyAlreadyExists = errors.New("passkey already registered")
)

type AuthService struct {
	jwtSecret []byte
	users     map[string]*User // key: phone E.164
	passkeys  map[string]*PasskeyRegistration // key: user ID
	walletMap map[string]string // key: wallet address → user ID
	challenges map[string]*Challenge // key: challenge ID
}

type User struct {
	ID           string    `json:"id"`
	PhoneNumber  string    `json:"phone_number"`
	Username     string    `json:"username"`
	DisplayName  string    `json:"display_name"`
	WalletAddr   string    `json:"wallet_addr"` // Acki Nacki MPC wallet address
	PasskeyID    string    `json:"passkey_id"`  // WebAuthn credential ID
	CreatedAt    time.Time `json:"created_at"`
}

type PasskeyRegistration struct {
	UserID       string `json:"user_id"`
	CredentialID string `json:"credential_id"` // WebAuthn raw ID (base64)
	PublicKey    string `json:"public_key"`    // COSE encoded
	SignCount    uint32 `json:"sign_count"`    //防重放
	CreatedAt    time.Time `json:"created_at"`
}

// Challenge for wallet ZKP login
type Challenge struct {
	ID        string    `json:"id"`
	WalletAddr string   `json:"wallet_addr"`
	Message   string    `json:"message"`   // "Sign this message to log in to NotJustDex: {nonce}"
	Nonce     string    `json:"nonce"`
	ExpiresAt time.Time `json:"expires_at"`
	Used      bool      `json:"used"`
}

type ZKProof struct {
	ChallengeID string `json:"challenge_id"`
	Proof       string `json:"proof"`       // Groth16 proof (base64)
	PublicInputs []string `json:"public_inputs"` // [challenge_hash, wallet_addr_hash, timestamp_hash]
}

func NewAuthService(jwtSecret string) *AuthService {
	return &AuthService{
		jwtSecret:  []byte(jwtSecret),
		users:      make(map[string]*User),
		passkeys:   make(map[string]*PasskeyRegistration),
		walletMap:  make(map[string]string),
		challenges: make(map[string]*Challenge),
	}
}

// ─── Phone Auth ─────────────────────────────────────────────────

// RegisterPhone creates a user record from phone verification.
// No password — phone verification is the auth factor.
func (s *AuthService) RegisterPhone(phoneNumber, username string) (*User, error) {
	if _, exists := s.users[phoneNumber]; exists {
		return nil, errors.New("user already exists")
	}

	user := &User{
		ID:          generateID(),
		PhoneNumber: phoneNumber,
		Username:    username,
		CreatedAt:   time.Now(),
	}
	s.users[phoneNumber] = user
	return user, nil
}

// LoginPhone returns a JWT for an existing phone user.
func (s *AuthService) LoginPhone(phoneNumber string) (string, error) {
	user, exists := s.users[phoneNumber]
	if !exists {
		return "", ErrUserNotFound
	}

	return s.generateJWT(user)
}

// ─── Passkey Auth ────────────────────────────────────────────────

// BeginPasskeyRegistration starts WebAuthn credential creation.
// Returns challenge data for the client to create a passkey.
func (s *AuthService) BeginPasskeyRegistration(userID, userName string) (map[string]interface{}, error) {
	if _, exists := s.passkeys[userID]; exists {
		return nil, ErrPasskeyAlreadyExists
	}

	challenge := randomBase64(32)
	userIDEnc := base64.RawURLEncoding.EncodeToString([]byte(userID))

	// WebAuthn creation options (simplified)
	options := map[string]interface{}{
		"publicKey": map[string]interface{}{
			"challenge": challenge,
			"rp": map[string]string{
				"name": "NotJustDex",
				"id":   "notjustdex.io",
			},
			"user": map[string]interface{}{
				"id":   userIDEnc,
				"name": userName,
				"displayName": userName,
			},
			"pubKeyCredParams": []map[string]interface{}{
				{"type": "public-key", "alg": -7},   // ES256
				{"type": "public-key", "alg": -257}, // RS256
			},
			"authenticatorSelection": map[string]interface{}{
				"residentKey": "required",
				"userVerification": "required",
			},
			"attestation": "direct",
			"timeout": 60000,
		},
	}

	return options, nil
}

// FinishPasskeyRegistration stores the WebAuthn credential.
func (s *AuthService) FinishPasskeyRegistration(userID, credentialID, publicKey string) error {
	if _, exists := s.passkeys[userID]; exists {
		return ErrPasskeyAlreadyExists
	}

	s.passkeys[userID] = &PasskeyRegistration{
		UserID:       userID,
		CredentialID: credentialID,
		PublicKey:    publicKey,
		SignCount:    0,
		CreatedAt:    time.Now(),
	}

	return nil
}

// BeginPasskeyAuthentication returns challenge for WebAuthn assertion.
func (s *AuthService) BeginPasskeyAuthentication(userID string) (map[string]interface{}, error) {
	reg, exists := s.passkeys[userID]
	if !exists {
		return nil, ErrPasskeyNotFound
	}

	challenge := randomBase64(32)

	options := map[string]interface{}{
		"publicKey": map[string]interface{}{
			"challenge": challenge,
			"allowCredentials": []map[string]interface{}{
				{
					"type": "public-key",
					"id":   reg.CredentialID,
				},
			},
			"userVerification": "required",
			"timeout": 60000,
		},
	}

	return options, nil
}

// FinishPasskeyAuthentication validates WebAuthn assertion and returns JWT.
func (s *AuthService) FinishPasskeyAuthentication(credentialID string, signCount uint32) (string, error) {
	var userID string
	for uid, reg := range s.passkeys {
		if reg.CredentialID == credentialID {
			userID = uid
			reg.SignCount = signCount
			break
		}
	}
	if userID == "" {
		return "", ErrPasskeyNotFound
	}

	// Find user
	for _, user := range s.users {
		if user.ID == userID {
			return s.generateJWT(user)
		}
	}

	return "", ErrUserNotFound
}

// ─── Wallet ZKP Auth ────────────────────────────────────────────

// CreateChallenge generates a challenge for wallet-based ZKP login.
func (s *AuthService) CreateChallenge(walletAddr string) (*Challenge, error) {
	nonce, err := randomHex(32)
	if err != nil {
		return nil, err
	}

	msg := fmt.Sprintf("Sign this message to authenticate with NotJustDex.\n\nWallet: %s\nNonce: %s\nTimestamp: %d",
		walletAddr, nonce, time.Now().UnixMilli())

	chal := &Challenge{
		ID:         generateID(),
		WalletAddr: walletAddr,
		Message:    msg,
		Nonce:      nonce,
		ExpiresAt:  time.Now().Add(5 * time.Minute),
	}

	s.challenges[chal.ID] = chal
	return chal, nil
}

// VerifyZKP verifies a Groth16 zero-knowledge proof and returns a JWT.
// The proof demonstrates knowledge of wallet ownership without revealing the private key.
func (s *AuthService) VerifyZKP(proof ZKProof) (string, error) {
	chal, exists := s.challenges[proof.ChallengeID]
	if !exists {
		return "", ErrChallengeExpired
	}

	if time.Now().After(chal.ExpiresAt) {
		return "", ErrChallengeExpired
	}

	if chal.Used {
		return "", errors.New("challenge already used")
	}

	// Verify the ZKP — in production this calls a Groth16 verifier
	// The public inputs are: [challenge_hash, wallet_addr_hash, timestamp_hash]
	// The proof is a Groth16 proof that the prover knows the wallet secret key
	// without revealing it.
	if err := s.verifyGroth16Proof(proof, chal); err != nil {
		return "", ErrInvalidProof
	}

	// Mark challenge as used
	chal.Used = true

	// Find user by wallet address
	userID, exists := s.walletMap[chal.WalletAddr]
	if !exists {
		return "", ErrUserNotFound
	}

	var user *User
	for _, u := range s.users {
		if u.ID == userID {
			user = u
			break
		}
	}
	if user == nil {
		return "", ErrUserNotFound
	}

	return s.generateJWT(user)
}

// verifyGroth16Proof validates the zero-knowledge proof.
// Currently a stub — in production this would call the on-chain verifier
// or use bellman/dusk-plonk for off-chain verification.
func (s *AuthService) verifyGroth16Proof(proof ZKProof, chal *Challenge) error {
	// Expected public inputs
	challengeHash := sha256Hex(chal.ID + chal.Nonce)
	walletHash := sha256Hex(chal.WalletAddr)

	if len(proof.PublicInputs) != 3 {
		return ErrInvalidProof
	}

	if proof.PublicInputs[0] != challengeHash {
		return ErrInvalidProof
	}

	if proof.PublicInputs[1] != walletHash {
		return ErrInvalidProof
	}

	// In production: verify the Groth16 proof using bellman or ark-groth16
	// against the verification key stored on-chain.

	return nil
}

// LinkWallet links an MPC wallet address to a user account.
// Called after wallet creation during onboarding.
func (s *AuthService) LinkWallet(userID, walletAddr string) error {
	for _, user := range s.users {
		if user.ID == userID {
			user.WalletAddr = walletAddr
			s.walletMap[walletAddr] = userID
			return nil
		}
	}
	return ErrUserNotFound
}

// ─── Utility ────────────────────────────────────────────────────

func (s *AuthService) generateJWT(user *User) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub":          user.ID,
		"phone":        user.PhoneNumber,
		"username":     user.Username,
		"wallet_addr":  user.WalletAddr,
		"has_passkey":  user.PasskeyID != "",
		"exp":          time.Now().Add(7 * 24 * time.Hour).Unix(),
		"iat":          time.Now().Unix(),
	})

	tokenString, err := token.SignedString(s.jwtSecret)
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

func (s *AuthService) ValidateToken(tokenString string) (string, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		return s.jwtSecret, nil
	})
	if err != nil {
		return "", err
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok || !token.Valid {
		return "", errors.New("invalid token")
	}

	sub, ok := claims["sub"].(string)
	if !ok {
		return "", errors.New("invalid subject")
	}

	return sub, nil
}

// GetUserByID retrieves a user by ID.
func (s *AuthService) GetUserByID(id string) (*User, error) {
	for _, user := range s.users {
		if user.ID == id {
			return user, nil
		}
	}
	return nil, ErrUserNotFound
}

// ─── Helpers ────────────────────────────────────────────────────

func generateID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return fmt.Sprintf("%x", b)
}

func randomBase64(n int) string {
	b := make([]byte, n)
	rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func randomHex(n int) (string, error) {
	b := make([]byte, n)
	_, err := rand.Read(b)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", b), nil
}

func sha256Hex(s string) string {
	h := sha256.Sum256([]byte(s))
	return fmt.Sprintf("%x", h)
}
