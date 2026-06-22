package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/notjustdex/feed/internal/handler"
	"github.com/notjustdex/feed/internal/models"
	"github.com/notjustdex/feed/internal/repository"
	"github.com/notjustdex/feed/internal/service"
)

func main() {
	repo := repository.NewFeedRepository()
	svc := service.NewFeedService(repo)
	h := handler.NewFeedHandler(svc)

	// Seed some demo content
	seedContent(repo)

	mux := http.NewServeMux()

	mux.HandleFunc("/health/live", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"alive"}`))
	})

	mux.HandleFunc("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ready"}`))
	})

	mux.Handle("/feed/", h)

	// Interaction endpoints
	mux.HandleFunc("/feed/like", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			UserID string `json:"user_id"`
			ItemID string `json:"item_id"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		svc.LikeItem(req.UserID, req.ItemID)
		w.WriteHeader(http.StatusOK)
	})

	mux.HandleFunc("/feed/unlike", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			UserID string `json:"user_id"`
			ItemID string `json:"item_id"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		svc.UnlikeItem(req.UserID, req.ItemID)
		w.WriteHeader(http.StatusOK)
	})

	mux.HandleFunc("/feed/view", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}
		svc.ViewPost(r.URL.Query().Get("item_id"))
		w.WriteHeader(http.StatusOK)
	})

	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8083"
	}

	log.Printf("feed service listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}

func seedContent(repo *repository.FeedRepository) {
	seed := []struct {
		itemType string
		authorID string
		content  string
		mediaURL string
	}{
		{"video", "author_001", "Morning run in the park! 🏃‍♂️", "https://notjustdex.io/media/videos/001.mp4"},
		{"image", "author_002", "Sunset from the rooftop 🌅", "https://notjustdex.io/media/images/002.jpg"},
		{"text", "author_003", "Hot take: The best code is the code you don't write. Think about it.", ""},
		{"video", "author_001", "My puppy learned a new trick! 🐕", "https://notjustdex.io/media/videos/004.mp4"},
		{"image", "author_004", "New coffee shop downtown ☕", "https://notjustdex.io/media/images/005.jpg"},
		{"text", "author_005", "Thread: How we built NotJustDex from scratch 🧵", ""},
		{"video", "author_002", "Cooking tutorial: Perfect pasta aglio e olio", "https://notjustdex.io/media/videos/007.mp4"},
		{"image", "author_003", "Weekend hike views 🏔️", "https://notjustdex.io/media/images/008.jpg"},
		{"story", "author_004", "Good morning from Tokyo! 🇯🇵", "https://notjustdex.io/media/stories/009.jpg"},
		{"video", "author_005", "React Native vs Flutter — Honest comparison", "https://notjustdex.io/media/videos/010.mp4"},
	}

	for _, s := range seed {
		repo.AddItem(&models.FeedItem{
			ID:        "seed_" + s.mediaURL[len(s.mediaURL)-7:],
			Type:      models.FeedItemType(s.itemType),
			AuthorID:  s.authorID,
			Content:   s.content,
			MediaURL:  s.mediaURL,
			Likes:     seedLikes(s.mediaURL),
			Comments:  seedComments(s.mediaURL),
			Shares:    seedShares(s.mediaURL),
			Views:     seedViews(s.mediaURL),
			CreatedAt: seedTime(s.mediaURL),
			Score:     50.0,
		})
	}
}

func seedLikes(url string) int { return 42 + len(url)%100 }
func seedComments(url string) int { return 5 + len(url)%20 }
func seedShares(url string) int { return 2 + len(url)%10 }
func seedViews(url string) int { return 1000 + len(url)%5000 }
func seedTime(url string) time.Time {
	return time.Date(2026, 5, 1+len(url)%28, 10, 0, 0, 0, time.UTC)
}
