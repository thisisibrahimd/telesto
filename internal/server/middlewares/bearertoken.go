package middlewares

import (
	"log/slog"
	"net/http"
	"strings"
)

type BearerTokenMiddleware struct {
	token  string
	header string
	schema string
}

func (bt *BearerTokenMiddleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get(bt.header)
		authValues := strings.Split(authHeader, " ")
		if len(authValues) != 2 {
			slog.Error("malformatted auth header")
			w.WriteHeader(http.StatusUnauthorized)
			return
		}

		if authValues[0] != bt.schema {
			slog.Error("schema does not match")
			w.WriteHeader(http.StatusUnauthorized)
			return
		}

		if authValues[1] != bt.token {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func BearerToken(token string) func(http.Handler) http.Handler {
	m := &BearerTokenMiddleware{
		token:  token,
		header: "Authorization",
		schema: "Bearer",
	}
	return m.Handler
}
