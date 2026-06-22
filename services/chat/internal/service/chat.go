package service

import (
	"fmt"
	"time"

	"github.com/notjustdex/chat/internal/store"
)

type ChatService struct {
	store *store.MemoryStore
}

type CreateConversationInput struct {
	Type           string
	ParticipantIDs []string
}

func NewChatService(st *store.MemoryStore) *ChatService {
	return &ChatService{store: st}
}

func (s *ChatService) SendMessage(convID, senderID, content, contentType, replyToID string) *store.Message {
	msg := &store.Message{
		ID:             fmt.Sprintf("msg_%d", time.Now().UnixNano()),
		ConversationID: convID,
		SenderID:       senderID,
		Content:        content,
		ContentType:    contentType,
		SentAt:         time.Now(),
		ReplyToID:      replyToID,
	}
	s.store.SaveMessage(msg)
	return msg
}

func (s *ChatService) CreateConversation(input CreateConversationInput) *store.Conversation {
	conv := &store.Conversation{
		ID:             fmt.Sprintf("conv_%d", time.Now().UnixNano()),
		Type:           input.Type,
		ParticipantIDs: input.ParticipantIDs,
		CreatedAt:      time.Now(),
	}
	s.store.CreateConversation(conv)
	return conv
}

func (s *ChatService) GetConversations(userID string) []*store.Conversation {
	return s.store.GetConversationsForUser(userID)
}

func (s *ChatService) GetMessages(convID string, limit, offset int) []*store.Message {
	return s.store.GetMessages(convID, limit, offset)
}
