package middlewares

import "net/http"

type (
	contextKey string
	Middleware func(http.Handler) http.Handler
)
