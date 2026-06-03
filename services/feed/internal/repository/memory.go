package repository

import (
	"math"
	"sort"
	"sync"
	"time"

	"github.com/dexchats/feed/internal/models"
)

type FeedRepository struct {
	mu    sync.RWMutex
	items map[string]*models.FeedItem
}

func NewFeedRepository() *FeedRepository {
	return &FeedRepository{
		items: make(map[string]*models.FeedItem),
	}
}

func (r *FeedRepository) AddItem(item *models.FeedItem) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.items[item.ID] = item
}

func (r *FeedRepository) GetItem(id string) *models.FeedItem {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.items[id]
}

func (r *FeedRepository) GetFeed(limit int, cursor time.Time) []*models.FeedItem {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var items []*models.FeedItem
	for _, item := range r.items {
		if item.CreatedAt.Before(cursor) || cursor.IsZero() {
			items = append(items, item)
		}
	}

	sort.Slice(items, func(i, j int) bool {
		// Primary: score descending
		if math.Abs(items[i].Score-items[j].Score) > 0.01 {
			return items[i].Score > items[j].Score
		}
		return items[i].CreatedAt.After(items[j].CreatedAt)
	})

	if len(items) > limit {
		items = items[:limit]
	}
	return items
}

func (r *FeedRepository) LikeItem(itemID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if item, ok := r.items[itemID]; ok {
		item.Likes++
		r.recalculateScore(item)
	}
}

func (r *FeedRepository) UnlikeItem(itemID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if item, ok := r.items[itemID]; ok && item.Likes > 0 {
		item.Likes--
		r.recalculateScore(item)
	}
}

func (r *FeedRepository) IncrementComments(itemID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if item, ok := r.items[itemID]; ok {
		item.Comments++
		r.recalculateScore(item)
	}
}

func (r *FeedRepository) IncrementShares(itemID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if item, ok := r.items[itemID]; ok {
		item.Shares++
		r.recalculateScore(item)
	}
}

func (r *FeedRepository) IncrementViews(itemID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if item, ok := r.items[itemID]; ok {
		item.Views++
		r.recalculateScore(item)
	}
}

func (r *FeedRepository) recalculateScore(item *models.FeedItem) {
	// Time decay factor: newer content gets higher score
	ageHours := time.Since(item.CreatedAt).Hours()
	timeScore := 100.0 / (1.0 + ageHours*0.5)

	// Engagement score: weighted combination
	engagementScore := float64(item.Likes)*1.0 +
		float64(item.Comments)*2.0 +
		float64(item.Shares)*3.0 +
		float64(item.Views)*0.1

	// Video/story content boosted for dwell time
	var contentTypeBoost float64 = 1.0
	switch item.Type {
	case models.ItemTypeVideo:
		contentTypeBoost = 1.3
	case models.ItemTypeStory:
		contentTypeBoost = 1.2
	case models.ItemTypeImage:
		contentTypeBoost = 1.1
	}

	item.Score = (timeScore + engagementScore) * contentTypeBoost
}
