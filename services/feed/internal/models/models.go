package models

import "time"

type FeedItemType string

const (
	ItemTypeVideo    FeedItemType = "video"
	ItemTypeImage    FeedItemType = "image"
	ItemTypeText     FeedItemType = "text"
	ItemTypeStory    FeedItemType = "story"
	ItemTypeRepost   FeedItemType = "repost"
)

type FeedItem struct {
	ID        string       `json:"id"`
	Type      FeedItemType `json:"type"`
	AuthorID  string       `json:"author_id"`
	Author    *Author      `json:"author,omitempty"`
	Content   string       `json:"content,omitempty"`
	MediaURL  string       `json:"media_url,omitempty"`
	MediaType string       `json:"media_type,omitempty"` // image/jpeg, video/mp4, etc
	Thumbnail string       `json:"thumbnail,omitempty"`
	Duration  int          `json:"duration,omitempty"` // seconds for video
	Likes     int          `json:"likes"`
	Comments  int          `json:"comments"`
	Shares    int          `json:"shares"`
	Views     int          `json:"views"`
	HasLiked  bool         `json:"has_liked"`
	HasSaved  bool         `json:"has_saved"`
	Score     float64      `json:"score"`
	CreatedAt time.Time    `json:"created_at"`
}

type Author struct {
	ID          string `json:"id"`
	Username    string `json:"username"`
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url,omitempty"`
	IsVerified  bool   `json:"is_verified"`
}

type FeedResponse struct {
	Items    []*FeedItem `json:"items"`
	Cursor   string      `json:"cursor,omitempty"`
	HasMore  bool        `json:"has_more"`
}

type InteractionRequest struct {
	UserID string `json:"user_id"`
	ItemID string `json:"item_id"`
}

type CreatePostRequest struct {
	AuthorID  string       `json:"author_id"`
	Type      FeedItemType `json:"type"`
	Content   string       `json:"content,omitempty"`
	MediaURL  string       `json:"media_url,omitempty"`
	MediaType string       `json:"media_type,omitempty"`
	Thumbnail string       `json:"thumbnail,omitempty"`
	Duration  int          `json:"duration,omitempty"`
}
