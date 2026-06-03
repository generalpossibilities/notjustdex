module github.com/dexchats/auth

go 1.23

require (
	github.com/dexchats/lib v0.0.0
	connectrpc.com/connect v1.16.0
	google.golang.org/protobuf v1.34.0
	github.com/golang-jwt/jwt/v5 v5.2.1
	github.com/lib/pq v1.10.9
	golang.org/x/crypto v0.27.0
)

replace github.com/dexchats/lib => ../../lib/go
