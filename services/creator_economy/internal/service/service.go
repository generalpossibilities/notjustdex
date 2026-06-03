package service

import (
	"fmt"
	"time"
)

type Tip struct {
	ID        string  `json:"id"`
	FromUser  string  `json:"from_user"`
	ToUser    string  `json:"to_user"`
	Amount    float64 `json:"amount"`
	Token     string  `json:"token"` // NACKL, SHELL
	ContentID string  `json:"content_id,omitempty"`
	Message   string  `json:"message,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type Subscription struct {
	ID           string    `json:"id"`
	SubscriberID string    `json:"subscriber_id"`
	CreatorID    string    `json:"creator_id"`
	Tier         string    `json:"tier"` // basic, premium, exclusive
	Price        float64   `json:"price"`
	Token        string    `json:"token"`
	Active       bool      `json:"active"`
	StartedAt    time.Time `json:"started_at"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type CreatorEconomyService struct {
	tips          []*Tip
	subscriptions []*Subscription
}

func NewCreatorEconomyService() *CreatorEconomyService {
	return &CreatorEconomyService{}
}

func (s *CreatorEconomyService) SendTip(from, to string, amount float64, token, contentID, message string) *Tip {
	tip := &Tip{
		ID:        fmt.Sprintf("tip_%d", time.Now().UnixNano()),
		FromUser:  from,
		ToUser:    to,
		Amount:    amount,
		Token:     token,
		ContentID: contentID,
		Message:   message,
		CreatedAt: time.Now(),
	}
	s.tips = append(s.tips, tip)
	return tip
}

func (s *CreatorEconomyService) Subscribe(subscriberID, creatorID, tier string, price float64, token string) *Subscription {
	sub := &Subscription{
		ID:           fmt.Sprintf("sub_%d", time.Now().UnixNano()),
		SubscriberID: subscriberID,
		CreatorID:    creatorID,
		Tier:         tier,
		Price:        price,
		Token:        token,
		Active:       true,
		StartedAt:    time.Now(),
		ExpiresAt:    time.Now().AddDate(0, 1, 0), // 30 days
	}
	s.subscriptions = append(s.subscriptions, sub)
	return sub
}
