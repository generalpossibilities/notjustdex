package hub

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/dexchats/notifications/internal/store"
	"github.com/dexchats/notifications/internal/types"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type Client struct {
	UserID string
	Conn   *websocket.Conn
	Send   chan []byte
}

type NotificationHub struct {
	mu      sync.RWMutex
	clients map[string]*Client // userID -> client (one per user)
	store   *store.MemoryStore
}

func NewNotificationHub(st *store.MemoryStore) *NotificationHub {
	return &NotificationHub{
		clients: make(map[string]*Client),
		store:   st,
	}
}

func (h *NotificationHub) HandleWS(w http.ResponseWriter, r *http.Request) {
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
		Send:   make(chan []byte, 64),
	}

	// Close existing connection for this user
	h.mu.Lock()
	if existing, ok := h.clients[userID]; ok {
		close(existing.Send)
		existing.Conn.Close()
	}
	h.clients[userID] = client
	h.mu.Unlock()

	go h.writePump(client)
	h.readPump(client)
}

func (h *NotificationHub) writePump(client *Client) {
	defer client.Conn.Close()
	for msg := range client.Send {
		if err := client.Conn.WriteMessage(websocket.TextMessage, msg); err != nil {
			return
		}
	}
}

func (h *NotificationHub) readPump(client *Client) {
	defer func() {
		h.mu.Lock()
		if h.clients[client.UserID] == client {
			delete(h.clients, client.UserID)
		}
		h.mu.Unlock()
		client.Conn.Close()
	}()

	for {
		_, _, err := client.Conn.ReadMessage()
		if err != nil {
			break
		}
	}
}

func (h *NotificationHub) Deliver(notif *types.Notification) {
	// Store
	h.store.AddNotification(notif)

	// Try real-time delivery via WebSocket
	h.mu.RLock()
	client, ok := h.clients[notif.UserID]
	h.mu.RUnlock()

	if ok {
		msg, _ := json.Marshal(map[string]interface{}{
			"type":         "notification",
			"notification": notif,
		})
		select {
		case client.Send <- msg:
		default:
			// drop if channel full
		}
	}
}

func (h *NotificationHub) DeliverToUser(userID string, msg []byte) {
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
