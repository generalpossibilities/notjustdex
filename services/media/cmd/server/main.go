package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/dexchats/media/internal/pipeline"
	"github.com/dexchats/media/internal/store"
)

func main() {
	st := store.NewMemoryStore()
	pl := pipeline.NewPipeline("/data/uploads", "/data/media", os.Getenv("CDN_BASE"))

	mux := http.NewServeMux()

	mux.HandleFunc("/health/live", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"alive"}`))
	})

	mux.HandleFunc("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ready"}`))
	})

	mux.HandleFunc("/api/media/upload", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}

		userID := r.FormValue("user_id")
		mediaType := r.FormValue("type")

		file, header, err := r.FormFile("file")
		if err != nil {
			http.Error(w, "file required", http.StatusBadRequest)
			return
		}
		defer file.Close()

		assetID := uuid.New().String()
		uploadID := fmt.Sprintf("upload_%d", time.Now().UnixNano())

		// In production: save to disk/S3, run async pipeline
		asset := &pipeline.MediaAsset{
			ID:          assetID,
			UploadID:    uploadID,
			Type:        pipeline.MediaType(mediaType),
			OriginalURL: fmt.Sprintf("/uploads/%s/%s", userID, header.Filename),
			Status:      "ready",
		}

		st.AddUpload(&store.UploadRecord{
			ID:        uploadID,
			UserID:    userID,
			Asset:     asset,
			CreatedAt: time.Now(),
		})

		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(asset)
	})

	mux.HandleFunc("/api/media/status", func(w http.ResponseWriter, r *http.Request) {
		assetID := r.URL.Query().Get("asset_id")
		asset := st.GetAsset(assetID)
		if asset == nil {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		json.NewEncoder(w).Encode(asset)
	})

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8088"
	}

	log.Printf("media service on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
