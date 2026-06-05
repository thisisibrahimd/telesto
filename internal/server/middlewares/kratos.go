package middlewares

import (
	"fmt"
	"net/http"

	ory "github.com/ory/kratos-client-go/v26"
)

type ProtectedMiddleware struct {
	oryClient    *ory.APIClient
	authEndpoint string
}

func (k *ProtectedMiddleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		session, err := validateSession(k.oryClient, r)
		loginUrl := fmt.Sprintf("%s/self-service/login/browser", k.authEndpoint)
		if err != nil {
			http.Redirect(w, r, loginUrl, http.StatusSeeOther)
			return
		}
		if !*session.Active {
			http.Redirect(w, r, loginUrl, http.StatusSeeOther)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func Protected(oryClient *ory.APIClient, authEndpoint string) func(http.Handler) http.Handler {
	protected := &ProtectedMiddleware{oryClient: oryClient, authEndpoint: authEndpoint}
	return protected.Handler
}
