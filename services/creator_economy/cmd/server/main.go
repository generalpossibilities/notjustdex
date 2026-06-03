package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/dexchats/creator_economy/internal/service"
)

func main() {
	svc := service.NewCreatorEconomyService()

	mux := http.NewServeMux()

	mux.HandleFunc("/health/live", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"alive"}`))
	})

	mux.HandleFunc("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ready"}`))
	})

	mux.HandleFunc("/api/creator/tip", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			From      string  `json:"from"`
			To        string  `json:"to"`
			Amount    float64 `json:"amount"`
			Token     string  `json:"token"`
			ContentID string  `json:"content_id,omitempty"`
			Message   string  `json:"message,omitempty"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		tip := svc.SendTip(req.From, req.To, req.Amount, req.Token, req.ContentID, req.Message)
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(tip)
	})

	mux.HandleFunc("/api/creator/subscribe", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			SubscriberID string  `json:"subscriber_id"`
			CreatorID    string  `json:"creator_id"`
			Tier         string  `json:"tier"`
			Price        float64 `json:"price"`
			Token        string  `json:"token"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		sub := svc.Subscribe(req.SubscriberID, req.CreatorID, req.Tier, req.Price, req.Token)
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(sub)
	})

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8092"
	}
	log.Printf("creator economy service on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
