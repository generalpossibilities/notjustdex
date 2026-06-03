module github.com/dexchats/chat

go 1.23

require (
	github.com/dexchats/lib v0.0.0
	connectrpc.com/connect v1.16.0
	google.golang.org/protobuf v1.34.0
	github.com/gorilla/websocket v1.5.3
)

replace github.com/dexchats/lib => ../../lib/go
