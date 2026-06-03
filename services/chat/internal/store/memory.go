package store

import (
	"sync"
	"time"
)

type Message struct {
	ID             string    `json:"id"`
	ConversationID string    `json:"conversation_id"`
	SenderID       string    `json:"sender_id"`
	Content        string    `json:"content"`
	ContentType    string    `json:"content_type"`
	SentAt         time.Time `json:"sent_at"`
	ReplyToID      string    `json:"reply_to_id,omitempty"`
}

type Conversation struct {
	ID             string    `json:"id"`
	Type           string    `json:"type"`
	ParticipantIDs []string  `json:"participant_ids"`
	LastMessage    *Message  `json:"last_message,omitempty"`
	UnreadCount    int       `json:"unread_count"`
	CreatedAt      time.Time `json:"created_at"`
}

type MemoryStore struct {
	mu            sync.RWMutex
	conversations map[string]*Conversation
	messages      map[string][]*Message
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		conversations: make(map[string]*Conversation),
		messages:      make(map[string][]*Message),
	}
}

func (s *MemoryStore) CreateConversation(c *Conversation) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.conversations[c.ID] = c
	s.messages[c.ID] = make([]*Message, 0)
}

func (s *MemoryStore) GetConversation(id string) *Conversation {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.conversations[id]
}

func (s *MemoryStore) GetConversationsForUser(userID string) []*Conversation {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var result []*Conversation
	for _, c := range s.conversations {
		for _, pid := range c.ParticipantIDs {
			if pid == userID {
				result = append(result, c)
				break
			}
		}
	}
	return result
}

func (s *MemoryStore) SaveMessage(m *Message) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.messages[m.ConversationID] = append(s.messages[m.ConversationID], m)
	if conv := s.conversations[m.ConversationID]; conv != nil {
		conv.LastMessage = m
	}
}

func (s *MemoryStore) GetMessages(conversationID string, limit, offset int) []*Message {
	s.mu.RLock()
	defer s.mu.RUnlock()
	msgs := s.messages[conversationID]
	if msgs == nil {
		return nil
	}
	if offset >= len(msgs) {
		return nil
	}
	start := len(msgs) - offset - limit
	if start < 0 {
		start = 0
	}
	end := len(msgs) - offset
	if end > len(msgs) {
		end = len(msgs)
	}
	return msgs[start:end]
}
