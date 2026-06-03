package main

import (
	"log"
	"net/http"

	"github.com/dexchats/analytics/internal/handler"
	"github.com/dexchats/analytics/internal/service"
)

func main() {
	svc := service.NewAnalyticsService()
	h := handler.NewAnalyticsHandler(svc)

	mux := http.NewServeMux()

	mux.HandleFunc("/health/live", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"alive"}`))
	})

	mux.HandleFunc("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ready"}`))
	})

	mux.Handle("/analytics/", h)

	log.Println("analytics service listening on :8090")
	log.Fatal(http.ListenAndServe(":8090", mux))
}
