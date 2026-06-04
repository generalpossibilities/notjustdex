package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/dexchats/moderation/internal/ml"
	"github.com/dexchats/moderation/internal/store"
)

func main() {
	modPipeline := ml.NewModerationPipeline()
	reportStore := store.NewMemoryStore()

	mux := http.NewServeMux()

	mux.HandleFunc("/health/live", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"alive"}`))
	})

	mux.HandleFunc("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ready"}`))
	})

	// Content moderation endpoint — called at upload time
	mux.HandleFunc("/api/moderation/check", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}

		var req struct {
			ContentID   string        `json:"content_id"`
			ContentType ml.ContentType `json:"content_type"`
			Text        string        `json:"text,omitempty"`
			MediaURL    string        `json:"media_url,omitempty"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		var result *ml.ModerationResult
		switch req.ContentType {
		case ml.ContentText:
			result = modPipeline.ModerateText(req.ContentID, req.Text)
		case ml.ContentImage:
			result = modPipeline.ModerateImage(req.ContentID, req.MediaURL)
		default:
			result = &ml.ModerationResult{
				ContentID:   req.ContentID,
				ContentType: req.ContentType,
			}
		}

		// Auto-flag for human review if confidence below threshold
		if result.IsFlagged && result.Confidence < 0.95 {
			result.NeedsHumanReview = true
			reportStore.AddReport(&store.Report{
				ID:          fmt.Sprintf("report_%d", time.Now().UnixNano()),
				ContentID:   req.ContentID,
				ContentType: req.ContentType,
				Reason:      result.FlagReason,
				Status:      store.ReportPending,
				ModResult:   result,
				CreatedAt:   time.Now(),
			})
		}

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(result)
	})

	// Report endpoint — user reports content
	mux.HandleFunc("/api/moderation/report", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			ContentID   string        `json:"content_id"`
			ContentType ml.ContentType `json:"content_type"`
			ReporterID  string        `json:"reporter_id"`
			Reason      string        `json:"reason"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		reportStore.AddReport(&store.Report{
			ID:          fmt.Sprintf("report_%d", time.Now().UnixNano()),
			ContentID:   req.ContentID,
			ContentType: req.ContentType,
			ReporterID:  req.ReporterID,
			Reason:      req.Reason,
			Status:      store.ReportPending,
			CreatedAt:   time.Now(),
		})
		w.WriteHeader(http.StatusCreated)
	})

	// Pending reports for human review queue
	mux.HandleFunc("/api/moderation/pending", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(reportStore.GetPending())
	})

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8090"
	}

	log.Printf("moderation service on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
