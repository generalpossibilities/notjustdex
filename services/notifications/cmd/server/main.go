package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/dexchats/notifications/internal/hub"
	"github.com/dexchats/notifications/internal/store"
	"github.com/dexchats/notifications/internal/types"
)

func main() {
	st := store.NewMemoryStore()
	notifHub := hub.NewNotificationHub(st)

	mux := http.NewServeMux()

	mux.HandleFunc("/health/live", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"alive"}`))
	})

	mux.HandleFunc("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ready"}`))
	})

	// WebSocket for real-time notifications
	mux.HandleFunc("/ws", notifHub.HandleWS)

	// REST API
	mux.HandleFunc("/api/notifications", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		userID := r.URL.Query().Get("user_id")

		switch r.Method {
		case http.MethodGet:
			limitStr := r.URL.Query().Get("limit")
			limit := 20
			if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 50 {
				limit = l
			}
			offsetStr := r.URL.Query().Get("offset")
			offset := 0
			if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
				offset = o
			}
			notifs := st.GetNotifications(userID, limit, offset)
			unread := st.UnreadCount(userID)
			_ = json.NewEncoder(w).Encode(types.NotificationResponse{
				Notifications: notifs,
				UnreadCount:   unread,
			})

		case http.MethodPost:
			var req types.Notification
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			req.ID = fmt.Sprintf("notif_%d", time.Now().UnixNano())
			req.CreatedAt = time.Now()
			req.Read = false
			notifHub.Deliver(&req)
			w.WriteHeader(http.StatusCreated)
			_ = json.NewEncoder(w).Encode(req)

		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/api/notifications/read", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}
		userID := r.URL.Query().Get("user_id")
		var req struct {
			IDs []string `json:"ids"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		if len(req.IDs) == 0 {
			st.MarkAllRead(userID)
		} else {
			st.MarkRead(userID, req.IDs)
		}
		w.WriteHeader(http.StatusOK)
	})

	mux.HandleFunc("/api/devices/register", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}
		var token types.DeviceToken
		if err := json.NewDecoder(r.Body).Decode(&token); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		st.RegisterDevice(&token)
		w.WriteHeader(http.StatusOK)
	})

	mux.HandleFunc("/api/notifications/send", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}
		var req types.NotificationRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		notif := &types.Notification{
			ID:         fmt.Sprintf("notif_%d", time.Now().UnixNano()),
			UserID:     req.UserID,
			Type:       req.Type,
			Title:      req.Title,
			Body:       req.Body,
			Data:       req.Data,
			ActorID:    req.ActorID,
			ActorName:  req.ActorName,
			CreatedAt:  time.Now(),
		}
		notifHub.Deliver(notif)
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(notif)
	})

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8087"
	}

	log.Printf("notifications service on %s (ws://%s/ws)", addr, addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
