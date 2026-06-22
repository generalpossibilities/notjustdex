package ws

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/notjustdex/chat/internal/service"
	"github.com/notjustdex/chat/internal/store"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type Client struct {
	UserID string
	Conn   *websocket.Conn
	Send   chan []byte
}

type Hub struct {
	mu      sync.RWMutex
	clients map[string]*Client
	svc     *service.ChatService
}

type IncomingMessage struct {
	Type       string `json:"type"`
	ConvID     string `json:"conversation_id,omitempty"`
	Content    string `json:"content,omitempty"`
	ContentType string `json:"content_type,omitempty"`
	TargetID   string `json:"target_id,omitempty"`
}

type OutgoingMessage struct {
	Type    string       `json:"type"`
	Message *store.Message `json:"message,omitempty"`
	Conv    *store.Conversation `json:"conversation,omitempty"`
	UserID  string       `json:"user_id,omitempty"`
	IsTyping bool        `json:"is_typing,omitempty"`
}

func NewHub(svc *service.ChatService) *Hub {
	return &Hub{
		clients: make(map[string]*Client),
		svc:     svc,
	}
}

func (h *Hub) HandleWS(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Query().Get("user_id")
	if userID == "" {
		http.Error(w, "user_id required", http.StatusBadRequest)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("ws upgrade: %v", err)
		return
	}

	client := &Client{
		UserID: userID,
		Conn:   conn,
		Send:   make(chan []byte, 256),
	}

	h.mu.Lock()
	h.clients[userID] = client
	h.mu.Unlock()

	go h.writePump(client)
	h.readPump(client)
}

func (h *Hub) writePump(client *Client) {
	defer client.Conn.Close()
	for msg := range client.Send {
		if err := client.Conn.WriteMessage(websocket.TextMessage, msg); err != nil {
			return
		}
	}
}

func (h *Hub) readPump(client *Client) {
	defer func() {
		h.mu.Lock()
		delete(h.clients, client.UserID)
		h.mu.Unlock()
		client.Conn.Close()
	}()

	for {
		_, raw, err := client.Conn.ReadMessage()
		if err != nil {
			break
		}

		var msg IncomingMessage
		if err := json.Unmarshal(raw, &msg); err != nil {
			continue
		}

		h.routeMessage(client, &msg)
	}
}

func (h *Hub) routeMessage(sender *Client, msg *IncomingMessage) {
	switch msg.Type {
	case "send_message":
		m := h.svc.SendMessage(msg.ConvID, sender.UserID, msg.Content, msg.ContentType, "")
		out, _ := json.Marshal(OutgoingMessage{
			Type:    "new_message",
			Message: m,
		})

		conv := h.svc.GetConversations(sender.UserID)
		for _, c := range conv {
			if c.ID == msg.ConvID {
				for _, pid := range c.ParticipantIDs {
					h.mu.RLock()
					client, ok := h.clients[pid]
					h.mu.RUnlock()
					if ok {
						select {
						case client.Send <- out:
						default:
						}
					}
				}
				break
			}
		}

	case "typing":
		conv := h.svc.GetConversations(sender.UserID)
		for _, c := range conv {
			if c.ID == msg.ConvID {
				out, _ := json.Marshal(OutgoingMessage{
					Type:     "typing",
					UserID:   sender.UserID,
					IsTyping: true,
				})
				for _, pid := range c.ParticipantIDs {
					if pid != sender.UserID {
						h.mu.RLock()
						client, ok := h.clients[pid]
						h.mu.RUnlock()
						if ok {
							select {
							case client.Send <- out:
							default:
							}
						}
					}
				}
				break
			}
		}
	}
}

func (h *Hub) BroadcastToUser(userID string, msg []byte) {
	h.mu.RLock()
	client, ok := h.clients[userID]
	h.mu.RUnlock()
	if ok {
		select {
		case client.Send <- msg:
		default:
		}
	}
}
