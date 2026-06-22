package handler

import (
	"encoding/json"
	"net/http"

	"github.com/notjustdex/auth/internal/service"
)

type AuthHandler struct {
	svc *service.AuthService
}

func NewAuthHandler(svc *service.AuthService) *AuthHandler {
	return &AuthHandler{svc: svc}
}

func (h *AuthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	switch r.URL.Path {
	case "/auth/v1/register/phone":
		h.registerPhone(w, r)
	case "/auth/v1/login/phone":
		h.loginPhone(w, r)
	case "/auth/v1/passkey/register/begin":
		h.beginPasskeyRegister(w, r)
	case "/auth/v1/passkey/register/finish":
		h.finishPasskeyRegister(w, r)
	case "/auth/v1/passkey/auth/begin":
		h.beginPasskeyAuth(w, r)
	case "/auth/v1/passkey/auth/finish":
		h.finishPasskeyAuth(w, r)
	case "/auth/v1/wallet/challenge":
		h.createChallenge(w, r)
	case "/auth/v1/wallet/verify":
		h.verifyZKP(w, r)
	case "/auth/v1/wallet/link":
		h.linkWallet(w, r)
	case "/auth/v1/validate":
		h.validateToken(w, r)
	default:
		http.NotFound(w, r)
	}
}

// ─── Phone ──────────────────────────────────────────────────────

func (h *AuthHandler) registerPhone(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		PhoneNumber string `json:"phone_number"`
		Username    string `json:"username"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	user, err := h.svc.RegisterPhone(req.PhoneNumber, req.Username)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusConflict)
		return
	}

	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"user_id":  user.ID,
		"username": user.Username,
	})
}

func (h *AuthHandler) loginPhone(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		PhoneNumber string `json:"phone_number"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	token, err := h.svc.LoginPhone(req.PhoneNumber)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusUnauthorized)
		return
	}

	_ = json.NewEncoder(w).Encode(map[string]string{"token": token})
}

// ─── Passkey ────────────────────────────────────────────────────

func (h *AuthHandler) beginPasskeyRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		UserID   string `json:"user_id"`
		UserName string `json:"user_name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	options, err := h.svc.BeginPasskeyRegistration(req.UserID, req.UserName)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusConflict)
		return
	}

	_ = json.NewEncoder(w).Encode(options)
}

func (h *AuthHandler) finishPasskeyRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		UserID       string `json:"user_id"`
		CredentialID string `json:"credential_id"`
		PublicKey    string `json:"public_key"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	if err := h.svc.FinishPasskeyRegistration(req.UserID, req.CredentialID, req.PublicKey); err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusConflict)
		return
	}

	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (h *AuthHandler) beginPasskeyAuth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		UserID string `json:"user_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	options, err := h.svc.BeginPasskeyAuthentication(req.UserID)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusUnauthorized)
		return
	}

	_ = json.NewEncoder(w).Encode(options)
}

func (h *AuthHandler) finishPasskeyAuth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		CredentialID string `json:"credential_id"`
		SignCount    uint32 `json:"sign_count"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	token, err := h.svc.FinishPasskeyAuthentication(req.CredentialID, req.SignCount)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusUnauthorized)
		return
	}

	_ = json.NewEncoder(w).Encode(map[string]string{"token": token})
}

// ─── Wallet ZKP ─────────────────────────────────────────────────

func (h *AuthHandler) createChallenge(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		WalletAddr string `json:"wallet_addr"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	chal, err := h.svc.CreateChallenge(req.WalletAddr)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}

	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"challenge_id": chal.ID,
		"message":      chal.Message,
	})
}

func (h *AuthHandler) verifyZKP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var proof service.ZKProof
	if err := json.NewDecoder(r.Body).Decode(&proof); err != nil {
		http.Error(w, `{"error":"invalid proof"}`, http.StatusBadRequest)
		return
	}

	token, err := h.svc.VerifyZKP(proof)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusUnauthorized)
		return
	}

	_ = json.NewEncoder(w).Encode(map[string]string{"token": token})
}

func (h *AuthHandler) linkWallet(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		UserID     string `json:"user_id"`
		WalletAddr string `json:"wallet_addr"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	if err := h.svc.LinkWallet(req.UserID, req.WalletAddr); err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
		return
	}

	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

// ─── Validate ───────────────────────────────────────────────────

func (h *AuthHandler) validateToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	userID, err := h.svc.ValidateToken(req.Token)
	if err != nil {
		http.Error(w, `{"error":"invalid token"}`, http.StatusUnauthorized)
		return
	}

	user, err := h.svc.GetUserByID(userID)
	if err != nil {
		http.Error(w, `{"error":"user not found"}`, http.StatusNotFound)
		return
	}

	_ = json.NewEncoder(w).Encode(user)
}
