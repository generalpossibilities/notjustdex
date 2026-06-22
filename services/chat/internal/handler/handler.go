package handler

import (
	"github.com/notjustdex/chat/internal/service"
	"github.com/notjustdex/chat/internal/ws"
)

type ChatHandler struct {
	svc *service.ChatService
	hub *ws.Hub
}

func NewChatHandler(svc *service.ChatService, hub *ws.Hub) *ChatHandler {
	return &ChatHandler{svc: svc, hub: hub}
}
