package connect

import (
	"context"
	"log"

	"connectrpc.com/connect"
)

func NewLoggingInterceptor() connect.UnaryInterceptorFunc {
	return func(next connect.UnaryFunc) connect.UnaryFunc {
		return func(
			ctx context.Context,
			req connect.AnyRequest,
		) (connect.AnyResponse, error) {
			log.Printf("request: %s", req.Spec().Procedure)
			resp, err := next(ctx, req)
			if err != nil {
				log.Printf("error: %v", err)
			}
			return resp, err
		}
	}
}

func NewRecoveryInterceptor() connect.UnaryInterceptorFunc {
	return func(next connect.UnaryFunc) connect.UnaryFunc {
		return func(
			ctx context.Context,
			req connect.AnyRequest,
		) (resp connect.AnyResponse, err error) {
			defer func() {
				if r := recover(); r != nil {
					log.Printf("panic recovered: %v", r)
					err = connect.NewError(connect.CodeInternal, nil)
				}
			}()
			return next(ctx, req)
		}
	}
}
