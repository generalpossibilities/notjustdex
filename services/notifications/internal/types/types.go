package types

import "time"

type NotificationType string

const (
	NotifChatMessage    NotificationType = "chat_message"
	NotifFeedLike       NotificationType = "feed_like"
	NotifFeedComment    NotificationType = "feed_comment"
	NotifFeedShare      NotificationType = "feed_share"
	NotifFollow         NotificationType = "follow"
	NotifMention        NotificationType = "mention"
	NotifMiniApp        NotificationType = "mini_app"
	NotifSystem         NotificationType = "system"
)

type Notification struct {
	ID        string           `json:"id"`
	UserID    string           `json:"user_id"`
	Type      NotificationType `json:"type"`
	Title     string           `json:"title"`
	Body      string           `json:"body"`
	Data      map[string]string `json:"data,omitempty"`
	ActorID   string           `json:"actor_id,omitempty"`
	ActorName string           `json:"actor_name,omitempty"`
	ActorAvatar string         `json:"actor_avatar,omitempty"`
	Read      bool             `json:"read"`
	CreatedAt time.Time        `json:"created_at"`
}

type DeviceToken struct {
	UserID string `json:"user_id"`
	Token  string `json:"token"`
	Platform string `json:"platform"` // ios, android, web
}

type NotificationRequest struct {
	UserID    string           `json:"user_id"`
	Type      NotificationType `json:"type"`
	Title     string           `json:"title"`
	Body      string           `json:"body"`
	Data      map[string]string `json:"data,omitempty"`
	ActorID   string           `json:"actor_id,omitempty"`
	ActorName string           `json:"actor_name,omitempty"`
}

type NotificationResponse struct {
	Notifications []*Notification `json:"notifications"`
	UnreadCount   int             `json:"unread_count"`
}
