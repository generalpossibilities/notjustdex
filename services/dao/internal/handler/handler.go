package handler

import "github.com/dexchats/dao/internal/service"

type DAOHandler struct {
	svc *service.DAOService
}

func NewDAOHandler(svc *service.DAOService) *DAOHandler {
	return &DAOHandler{svc: svc}
}
