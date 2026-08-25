package public

import (
	"fmt"
	"log/slog"
	"net/http"
	"regexp"
	"slices"

	ory "github.com/ory/kratos-client-go/v26"
	"github.com/thisisibrahimd/telesto/templates/pages"
)

type AuthHandler struct {
	authEndpoint  string
	serverBaseUrl string
	oryAPIClient  *ory.APIClient
}

func newAuthHandler(authEndpoint, serverBaseUrl string, oryAPIClient *ory.APIClient) *AuthHandler {
	return &AuthHandler{authEndpoint: authEndpoint, serverBaseUrl: serverBaseUrl, oryAPIClient: oryAPIClient}
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	kratosloginUrl := fmt.Sprintf("%s/self-service/login/browser", h.authEndpoint)

	flowParam := r.URL.Query().Get("flow")
	if flowParam == "" {
		http.Redirect(w, r, kratosloginUrl, http.StatusSeeOther)
		return
	}

	csrfCookie := r.Header.Get("Cookie")

	getLoginFlow, getLoginFlowRes, err := h.oryAPIClient.FrontendAPI.GetLoginFlow(r.Context()).Id(flowParam).Cookie(csrfCookie).Execute()
	if err != nil {
		slog.Error("failed to complete login flow", slog.Any("error", err))
		if getLoginFlowRes != nil && getLoginFlowRes.StatusCode == http.StatusGone {
			http.Redirect(w, r, kratosloginUrl, http.StatusSeeOther)
			return
		}

		http.Error(w, "error loading auth state", http.StatusInternalServerError)
		return
	}

	pages.Login(getLoginFlow.Ui).Render(r.Context(), w)
}

// Register implements [PublicServerInterface].
func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	registrationUrl := fmt.Sprintf("%s/self-service/registration/browser", h.authEndpoint)

	flowParam := r.URL.Query().Get("flow")
	if flowParam == "" {
		http.Redirect(w, r, registrationUrl, http.StatusSeeOther)
		return
	}

	csrfCookieIndex := slices.IndexFunc(r.Cookies(), func(c *http.Cookie) bool { return regexp.MustCompile(`^csrf_token_`).MatchString(c.Name) })
	if csrfCookieIndex == -1 {
		http.Redirect(w, r, registrationUrl, http.StatusSeeOther)
		return
	}

	csrfCookie := r.Cookies()[csrfCookieIndex]
	if err := csrfCookie.Valid(); err != nil {
		http.Redirect(w, r, registrationUrl, http.StatusSeeOther)
		return
	}

	getRegisterFlow, getRegisterFlowRes, err := h.oryAPIClient.FrontendAPI.GetRegistrationFlow(r.Context()).Id(flowParam).Cookie(csrfCookie.String()).Execute()
	if err != nil {
		switch getRegisterFlowRes.StatusCode {
		case http.StatusNotFound:
			http.Redirect(w, r, registrationUrl, http.StatusSeeOther)
			return
		default:
			slog.Error("failed to get login flow info", slog.Any("error", err))
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
	}

	pages.Register(getRegisterFlow.Ui).Render(r.Context(), w)
}

// Logout implements [PublicServerInterface].
func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	createBrowserLogoutFlow, createBrowserLogoutFlowRes, err := h.oryAPIClient.FrontendAPI.CreateBrowserLogoutFlow(r.Context()).Cookie(r.Header.Get("Cookie")).Execute()
	if err != nil {
		if createBrowserLogoutFlowRes != nil {
			switch createBrowserLogoutFlowRes.StatusCode {
			case http.StatusNotFound:
				w.Header().Add("Location", h.serverBaseUrl)
				w.WriteHeader(http.StatusSeeOther)
				return
			default:
				slog.Error("failed to get logout flow info", slog.Any("error", err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		} else {
			slog.Error("failed to get logout flow info", slog.Any("error", err))
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
	}

	w.Header().Add("Location", createBrowserLogoutFlow.LogoutUrl)
	w.WriteHeader(http.StatusPermanentRedirect)
}
