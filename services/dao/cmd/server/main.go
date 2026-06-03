package main

import (
	"log"
	"net/http"

	"github.com/dexchats/dao/internal/handler"
	"github.com/dexchats/dao/internal/service"
)

func main() {
	svc := service.NewDAOService()
	h := handler.NewDAOHandler(svc)

	mux := http.NewServeMux()

	mux.HandleFunc("/health/live", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"alive"}`))
	})

	mux.HandleFunc("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ready"}`))
	})

	mux.Handle("/dao/", h)

	log.Println("dao service listening on :8092")
	log.Fatal(http.ListenAndServe(":8092", mux))
}
