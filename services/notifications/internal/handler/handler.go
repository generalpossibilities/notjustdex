package handler

import "github.com/dexchats/notifications/internal/service"

type NotificationsHandler struct {
	svc *service.NotificationsService
}

func NewNotificationsHandler(svc *service.NotificationsService) *NotificationsHandler {
	return &NotificationsHandler{svc: svc}
}
