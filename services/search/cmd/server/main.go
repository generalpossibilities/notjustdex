package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/dexchats/search/internal/index"
)

func main() {
	idx := index.NewMemoryIndex()

	// seed some demo data
	for _, d := range []index.Document{
		{ID: "alice", Type: index.DocUser, Title: "Alice", Content: "alice crypto dev", Tags: []string{"developer", "crypto"}},
		{ID: "bob", Type: index.DocUser, Title: "Bob", Content: "bob designer artist", Tags: []string{"design", "art"}},
		{ID: "wallet", Type: index.DocMiniApp, Title: "Wallet", Content: "wallet send receive tokens acki nacki", Tags: []string{"wallet", "finance"}},
		{ID: "dao", Type: index.DocMiniApp, Title: "DAO", Content: "dao vote governance proposals", Tags: []string{"dao", "governance"}},
	} {
		doc := d
		idx.Index(&doc)
	}

	mux := http.NewServeMux()

	mux.HandleFunc("/health/live", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"alive"}`))
	})

	mux.HandleFunc("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ready"}`))
	})

	mux.HandleFunc("/api/search", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		limitStr := r.URL.Query().Get("limit")
		limit := 10
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
			limit = l
		}
		results := idx.Search(q, limit)
		_ = json.NewEncoder(w).Encode(results)
	})

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8086"
	}
	log.Printf("search service on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
