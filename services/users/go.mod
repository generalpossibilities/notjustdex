module github.com/dexchats/users

go 1.23

require (
	github.com/dexchats/lib v0.0.0
	connectrpc.com/connect v1.16.0
	google.golang.org/protobuf v1.34.0
	github.com/lib/pq v1.10.9
)

replace github.com/dexchats/lib => ../../lib/go
