package main

import (
	"context"
	"fmt"
	"log"
	"net/http"

	"connectrpc.com/connect"
	dvaultv1 "github.com/notjustdex/d-vault/proto/dvault/v1"
	"github.com/notjustdex/d-vault/proto/dvault/v1/dvaultv1connect"
	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
)

type dvaultServer struct{}

func (s *dvaultServer) GetVault(
	ctx context.Context,
	req *connect.Request[dvaultv1.GetVaultRequest],
) (*connect.Response[dvaultv1.GetVaultResponse], error) {
	// Proxy: read from Acki Nacki contract via JSON-RPC
	// For now, returns empty
	return connect.NewResponse(&dvaultv1.GetVaultResponse{}), nil
}

func (s *dvaultServer) UpdateVault(
	ctx context.Context,
	req *connect.Request[dvaultv1.UpdateVaultRequest],
) (*connect.Response[dvaultv1.UpdateVaultResponse], error) {
	// Proxy: write to Acki Nacki contract via JSON-RPC
	// Signs tx using wallet key (Identity Kernel integration)
	return connect.NewResponse(&dvaultv1.UpdateVaultResponse{
		TxId: "pending",
	}), nil
}

func main() {
	mux := http.NewServeMux()
	path, handler := dvaultv1connect.NewDVaultServiceHandler(&dvaultServer{})
	mux.Handle(path, handler)

	addr := ":8090"
	fmt.Printf("d-vault service listening on %s\n", addr)
	log.Fatal(http.ListenAndServe(
		addr,
		h2c.NewHandler(mux, &http2.Server{}),
	))
}
