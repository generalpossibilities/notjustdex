package service

import (
	"fmt"
	"time"

	"github.com/dexchats/feed/internal/models"
	"github.com/dexchats/feed/internal/repository"
)

type FeedService struct {
	repo *repository.FeedRepository
}

func NewFeedService(repo *repository.FeedRepository) *FeedService {
	return &FeedService{repo: repo}
}

func (s *FeedService) GetFeed(userID string, cursor string, limit int) *models.FeedResponse {
	var cursorTime time.Time
	if cursor != "" {
		cursorTime, _ = time.Parse(time.RFC3339, cursor)
	}

	items := s.repo.GetFeed(limit, cursorTime)

	// Enrich with author data and user interaction state
	for _, item := range items {
		item.HasLiked = false // would check against user's liked set
		item.HasSaved = false
		item.Author = &models.Author{
			ID:          item.AuthorID,
			Username:    fmt.Sprintf("user_%s", item.AuthorID[:8]),
			DisplayName: fmt.Sprintf("User %s", item.AuthorID[:8]),
			AvatarURL:   "",
			IsVerified:  false,
		}
	}

	resp := &models.FeedResponse{
		Items: items,
	}
	if len(items) > 0 {
		resp.Cursor = items[len(items)-1].CreatedAt.Format(time.RFC3339)
		resp.HasMore = len(items) == limit
	}
	return resp
}

func (s *FeedService) CreatePost(req *models.CreatePostRequest) *models.FeedItem {
	item := &models.FeedItem{
		ID:        fmt.Sprintf("post_%d", time.Now().UnixNano()),
		Type:      req.Type,
		AuthorID:  req.AuthorID,
		Content:   req.Content,
		MediaURL:  req.MediaURL,
		MediaType: req.MediaType,
		Thumbnail: req.Thumbnail,
		Duration:  req.Duration,
		CreatedAt: time.Now(),
	}
	s.repo.AddItem(item)
	return item
}

func (s *FeedService) LikeItem(userID, itemID string) {
	s.repo.LikeItem(itemID)
}

func (s *FeedService) UnlikeItem(userID, itemID string) {
	s.repo.UnlikeItem(itemID)
}

func (s *FeedService) CommentOnPost(itemID string) {
	s.repo.IncrementComments(itemID)
}

func (s *FeedService) SharePost(itemID string) {
	s.repo.IncrementShares(itemID)
}

func (s *FeedService) ViewPost(itemID string) {
	s.repo.IncrementViews(itemID)
}
