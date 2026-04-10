package middlewares

import (
	"net/http"

	ory "github.com/ory/kratos-client-go/v26"
)

type ProtectedMiddleware struct {
	oryClient *ory.APIClient
}

func (k *ProtectedMiddleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		session, err := validateSession(k.oryClient, r)
		if err != nil {
			w.Header().Add("Location", "http://localhost:4434/self-service/login/browser")
			w.WriteHeader(http.StatusMovedPermanently)
			return
		}
		if !*session.Active {
			w.Header().Add("Location", "http://localhost:4434/self-service/login/browser")
			w.WriteHeader(http.StatusMovedPermanently)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func Protected(oryClient *ory.APIClient) func(http.Handler) http.Handler {
	protected := &ProtectedMiddleware{oryClient: oryClient}
	return protected.Handler
}
