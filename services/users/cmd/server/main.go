package main

import (
	"log"
	"net/http"
	"os"

	"github.com/dexchats/users/internal/handler"
	"github.com/dexchats/users/internal/service"
)

func main() {
	graphqlURL := os.Getenv("AN_GRAPHQL_URL")
	svc := service.NewUserService(graphqlURL)
	h := handler.NewUserHandler(svc)

	mux := http.NewServeMux()

	mux.HandleFunc("/health/live", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"alive"}`))
	})

	mux.HandleFunc("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ready"}`))
	})

	mux.Handle("/users/v1/", h)

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8082"
	}

	log.Printf("users service listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
