package handler

import "github.com/dexchats/creator_economy/internal/service"

type CreatorEconomyHandler struct {
	svc *service.CreatorEconomyService
}

func NewCreatorEconomyHandler(svc *service.CreatorEconomyService) *CreatorEconomyHandler {
	return &CreatorEconomyHandler{svc: svc}
}
