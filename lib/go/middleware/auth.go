package middleware

import (
	"context"
	"strings"
)

type contextKey string

const IdentityIDKey contextKey = "identity_id"

func ExtractBearerToken(authHeader string) string {
	if strings.HasPrefix(authHeader, "Bearer ") {
		return strings.TrimPrefix(authHeader, "Bearer ")
	}
	return ""
}

func WithIdentityID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, IdentityIDKey, id)
}

func GetIdentityID(ctx context.Context) string {
	if id, ok := ctx.Value(IdentityIDKey).(string); ok {
		return id
	}
	return ""
}
