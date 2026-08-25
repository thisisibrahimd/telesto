package middlewares

import (
	"context"
	"net/http"

	"github.com/mdobak/go-xerrors"
	ory "github.com/ory/kratos-client-go/v26"
)

var ErrNoSessionFound = xerrors.New("no session found in cookie")

const (
	SessionKey         contextKey = "session"
	SessionIsActiveKey contextKey = "session_is_active"
	UserIdKey          contextKey = "user_id"
)

type LoadSessionMiddleware struct {
	oryClient *ory.APIClient
}

func (h *LoadSessionMiddleware) Handler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		session, _ := validateSession(h.oryClient, r)
		if session != nil {
			if *session.Active {
				r = r.WithContext(SetSession(r.Context(), session))
			}
		}

		next.ServeHTTP(w, r)
	})
}

func validateSession(oClient *ory.APIClient, r *http.Request) (*ory.Session, error) {
	cookie := r.Header.Get("Cookie")
	if cookie == "" {
		return nil, ErrNoSessionFound
	}
	resp, _, err := oClient.FrontendAPI.ToSession(context.Background()).Cookie(cookie).Execute()
	if err != nil {
		return nil, err
	}
	return resp, nil
}

func SetSession(ctx context.Context, session *ory.Session) context.Context {
	return context.WithValue(ctx, SessionKey, session)
}

func GetSession(ctx context.Context) *ory.Session {
	s, _ := ctx.Value(SessionKey).(*ory.Session)
	return s
}

func GetSessionIsActive(ctx context.Context) bool {
	if s, ok := ctx.Value(SessionKey).(*ory.Session); ok {
		return s.GetActive()
	}
	return false
}

func GetUsername(ctx context.Context) string {
	if username, ok := ctx.Value(SessionKey).(*ory.Session).GetIdentity().Traits.(map[string]interface{})["username"].(string); ok {
		return username
	}
	return ""
}

func GetUserID(ctx context.Context) string {
	if !GetSessionIsActive(ctx) {
		return ""
	}
	session := GetSession(ctx)
	return session.GetIdentity().Id
}

func LoadSession(oryClient *ory.APIClient) func(http.Handler) http.Handler {
	loadSession := &LoadSessionMiddleware{oryClient: oryClient}
	return loadSession.Handler
}
