package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/dexchats/chat/internal/handler"
	"github.com/dexchats/chat/internal/service"
	"github.com/dexchats/chat/internal/store"
	"github.com/dexchats/chat/internal/ws"
)

func main() {
	st := store.NewMemoryStore()
	svc := service.NewChatService(st)
	hub := ws.NewHub(svc)
	h := handler.NewChatHandler(svc, hub)

	mux := http.NewServeMux()

	mux.HandleFunc("/health/live", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"alive"}`))
	})

	mux.HandleFunc("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ready"}`))
	})

	mux.HandleFunc("/ws", hub.HandleWS)

	mux.HandleFunc("/api/conversations", func(w http.ResponseWriter, r *http.Request) {
		userID := r.URL.Query().Get("user_id")
		convs := svc.GetConversations(userID)
		_ = json.NewEncoder(w).Encode(convs)
	})

	mux.HandleFunc("/api/conversations/create", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}
		var input struct {
			Type           string   `json:"type"`
			ParticipantIDs []string `json:"participant_ids"`
		}
		if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		conv := svc.CreateConversation(service.CreateConversationInput{
			Type:           input.Type,
			ParticipantIDs: input.ParticipantIDs,
		})
		_ = json.NewEncoder(w).Encode(conv)
	})

	mux.HandleFunc("/api/messages", func(w http.ResponseWriter, r *http.Request) {
		convID := r.URL.Query().Get("conversation_id")
		messages := svc.GetMessages(convID, 50, 0)
		_ = json.NewEncoder(w).Encode(messages)
	})

	mux.Handle("/chat.v1.ChatService/", h)

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8085"
	}

	log.Printf("chat service listening on %s (ws://%s/ws)", addr, addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
