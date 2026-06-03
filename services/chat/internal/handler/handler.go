package handler

import (
	"github.com/dexchats/chat/internal/service"
	"github.com/dexchats/chat/internal/ws"
)

type ChatHandler struct {
	svc *service.ChatService
	hub *ws.Hub
}

func NewChatHandler(svc *service.ChatService, hub *ws.Hub) *ChatHandler {
	return &ChatHandler{svc: svc, hub: hub}
}
