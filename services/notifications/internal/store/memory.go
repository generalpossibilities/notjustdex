package store

import (
	"sync"

	"github.com/dexchats/notifications/internal/types"
)

type MemoryStore struct {
	mu      sync.RWMutex
	notifs  map[string][]*types.Notification
	tokens  map[string][]*types.DeviceToken // userID -> tokens
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		notifs: make(map[string][]*types.Notification),
		tokens: make(map[string][]*types.DeviceToken),
	}
}

func (s *MemoryStore) AddNotification(n *types.Notification) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.notifs[n.UserID] = append(s.notifs[n.UserID], n)
}

func (s *MemoryStore) GetNotifications(userID string, limit, offset int) []*types.Notification {
	s.mu.RLock()
	defer s.mu.RUnlock()
	all := s.notifs[userID]
	if all == nil {
		return nil
	}
	start := len(all) - offset - limit
	if start < 0 {
		start = 0
	}
	end := len(all) - offset
	if end > len(all) {
		end = len(all)
	}
	return all[start:end]
}

func (s *MemoryStore) MarkRead(userID string, notifIDs []string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, notif := range s.notifs[userID] {
		for _, id := range notifIDs {
			if notif.ID == id {
				notif.Read = true
			}
		}
	}
}

func (s *MemoryStore) MarkAllRead(userID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, notif := range s.notifs[userID] {
		notif.Read = true
	}
}

func (s *MemoryStore) UnreadCount(userID string) int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	count := 0
	for _, n := range s.notifs[userID] {
		if !n.Read {
			count++
		}
	}
	return count
}

func (s *MemoryStore) RegisterDevice(token *types.DeviceToken) {
	s.mu.Lock()
	defer s.mu.Unlock()
	// deduplicate
	for _, t := range s.tokens[token.UserID] {
		if t.Token == token.Token {
			return
		}
	}
	s.tokens[token.UserID] = append(s.tokens[token.UserID], token)
}

func (s *MemoryStore) GetDeviceTokens(userID string) []*types.DeviceToken {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.tokens[userID]
}
