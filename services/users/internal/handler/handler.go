package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/dexchats/users/internal/service"
)

type UserHandler struct {
	svc *service.UserService
}

func NewUserHandler(svc *service.UserService) *UserHandler {
	return &UserHandler{svc: svc}
}

func (h *UserHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	switch r.URL.Path {
	case "/users/v1/create":
		h.createUser(w, r)
	case "/users/v1/get":
		h.getUser(w, r)
	case "/users/v1/update":
		h.updateProfile(w, r)
	case "/users/v1/avatar":
		h.uploadAvatar(w, r)
	case "/users/v1/check-username":
		h.checkUsername(w, r)
	case "/users/v1/resolve":
		h.resolveUsername(w, r)
	case "/users/v1/wallet":
		h.getWallet(w, r)
	case "/users/v1/seed/export":
		h.exportSeed(w, r)
	case "/users/v1/seed/rotate":
		h.rotateSeed(w, r)
	default:
		http.NotFound(w, r)
	}
}

func (h *UserHandler) createUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		PhoneNumber string `json:"phone_number"`
		Username    string `json:"username"`
		DisplayName string `json:"display_name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	if len(req.Username) < 4 {
		http.Error(w, `{"error":"username must be at least 4 characters"}`, http.StatusBadRequest)
		return
	}
	if req.DisplayName != "" && len(req.DisplayName) < 4 {
		http.Error(w, `{"error":"display name must be at least 4 characters"}`, http.StatusBadRequest)
		return
	}

	user, wallet, err := h.svc.CreateUser(req.PhoneNumber, req.Username, req.DisplayName)
	if err != nil {
		code := http.StatusInternalServerError
		if err.Error() == "username already taken on chain" {
			code = http.StatusConflict
		}
		http.Error(w, `{"error":"`+err.Error()+`"}`, code)
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"user":   user,
		"wallet": wallet,
	})
}

func (h *UserHandler) getUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		http.Error(w, `{"error":"missing id"}`, http.StatusBadRequest)
		return
	}

	user, err := h.svc.GetUser(id)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
		return
	}

	json.NewEncoder(w).Encode(user)
}

func (h *UserHandler) checkUsername(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	username := r.URL.Query().Get("username")
	available := h.svc.CheckUsernameAvailability(username)

	json.NewEncoder(w).Encode(map[string]interface{}{
		"username":   username,
		"available":  available,
	})
}

func (h *UserHandler) updateProfile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		UserID      string `json:"user_id"`
		DisplayName string `json:"display_name"`
		Bio         string `json:"bio"`
		AvatarURL   string `json:"avatar_url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	if req.DisplayName != "" && len(req.DisplayName) < 4 {
		http.Error(w, `{"error":"display name must be at least 4 characters"}`, http.StatusBadRequest)
		return
	}

	user, err := h.svc.UpdateProfile(req.UserID, req.DisplayName, req.Bio, req.AvatarURL)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
		return
	}

	json.NewEncoder(w).Encode(user)
}

func (h *UserHandler) uploadAvatar(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse multipart form (max 5MB)
	if err := r.ParseMultipartForm(5 << 20); err != nil {
		http.Error(w, `{"error":"file too large"}`, http.StatusBadRequest)
		return
	}

	userID := r.FormValue("user_id")
	if userID == "" {
		http.Error(w, `{"error":"missing user_id"}`, http.StatusBadRequest)
		return
	}

	file, header, err := r.FormFile("avatar")
	if err != nil {
		http.Error(w, `{"error":"missing avatar file"}`, http.StatusBadRequest)
		return
	}
	defer file.Close()

	// In production: upload to S3/IPFS, store URL
	// Stub: return a mock URL
	avatarURL := "https://storage.dexchats.io/avatars/" + userID + "/" + header.Filename

	user, err := h.svc.UpdateProfile(userID, "", "", avatarURL)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"avatar_url": avatarURL,
		"user":       user,
	})
}

func (h *UserHandler) resolveUsername(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	username := r.URL.Query().Get("username")
	user, err := h.svc.ResolveUsername(username)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
		return
	}

	json.NewEncoder(w).Encode(user)
}

func (h *UserHandler) getWallet(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	identityID := r.URL.Query().Get("identity_id")
	wallet, err := h.svc.GetWallet(identityID)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
		return
	}

	json.NewEncoder(w).Encode(wallet)
}

func (h *UserHandler) exportSeed(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		IdentityID string `json:"identity_id"`
		Password   string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	seed, err := h.svc.ExportMnemonic(req.IdentityID)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"seed_phrase": seed,
	})
}

func (h *UserHandler) rotateSeed(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		IdentityID string `json:"identity_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request"}`, http.StatusBadRequest)
		return
	}

	seed, err := h.svc.RotateSeedPhrase(req.IdentityID)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusNotFound)
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"seed_phrase": seed,
	})
}
