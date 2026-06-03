package handler

import (
	"github.com/dexchats/hus/internal/service"
)

type HUSHandler struct {
	svc *service.HUSService
}

func NewHUSHandler(svc *service.HUSService) *HUSHandler {
	return &HUSHandler{svc: svc}
}
