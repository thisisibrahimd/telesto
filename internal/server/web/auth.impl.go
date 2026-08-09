package web

import (
	"fmt"
	"log/slog"
	"net/http"
	"regexp"
	"slices"

	"github.com/thisisibrahimd/telesto/templates/pages"
)

// Login implements [WebServerInterface].
func (s *WebServer) Login(w http.ResponseWriter, r *http.Request) {
	loginUrl := fmt.Sprintf("%s/self-service/login/browser", s.authEndpoint)

	flowParam := r.URL.Query().Get("flow")
	if flowParam == "" {
		slog.Error("failed to get login flow id")
		http.Redirect(w, r, loginUrl, http.StatusSeeOther)
		return
	}

	csrfCookieIndex := slices.IndexFunc(r.Cookies(), func(c *http.Cookie) bool { return regexp.MustCompile(`^csrf_token_`).MatchString(c.Name) })
	if csrfCookieIndex == -1 {
		slog.Error("failed to get csrf cookie")
		http.Redirect(w, r, loginUrl, http.StatusSeeOther)
		return
	}

	csrfCookie := r.Cookies()[csrfCookieIndex]
	if err := csrfCookie.Valid(); err != nil {
		slog.Error("failed to get csrf cookie")
		http.Redirect(w, r, loginUrl, http.StatusSeeOther)
		return
	}

	if csrfCookie.String() == "" {
		slog.Error("csrf cookie empty")
		http.Redirect(w, r, loginUrl, http.StatusSeeOther)
		return

	} else {
		slog.Info(csrfCookie.String())
	}

	getLoginFlow, getLoginFlowRes, err := s.oryClient.FrontendAPI.GetLoginFlow(r.Context()).Id(flowParam).Cookie(csrfCookie.String()).Execute()
	if err != nil {
		slog.Error("failed to complete login flow", slog.Any("error", err))
		if getLoginFlowRes != nil {
			switch getLoginFlowRes.StatusCode {
			case http.StatusNotFound:
				w.Header().Add("Location", loginUrl)
				w.WriteHeader(http.StatusSeeOther)
				return
			default:
				slog.Error("failed to get login flow info", slog.Any("error", err))
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
		}
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	pages.Login(getLoginFlow.Ui).Render(r.Context(), w)
}

// Register implements [WebServerInterface].
func (s *WebServer) Register(w http.ResponseWriter, r *http.Request) {
	registrationUrl := fmt.Sprintf("%s/self-service/registration/browser", s.authEndpoint)

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

	getRegisterFlow, getRegisterFlowRes, err := s.oryClient.FrontendAPI.GetRegistrationFlow(r.Context()).Id(flowParam).Cookie(csrfCookie.String()).Execute()
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

// Logout implements [WebServerInterface].
func (s *WebServer) Logout(w http.ResponseWriter, r *http.Request) {
	createBrowserLogoutFlow, createBrowserLogoutFlowRes, err := s.oryClient.FrontendAPI.CreateBrowserLogoutFlow(r.Context()).Cookie(r.Header.Get("Cookie")).Execute()
	if err != nil {
		if createBrowserLogoutFlowRes != nil {
			switch createBrowserLogoutFlowRes.StatusCode {
			case http.StatusNotFound:
				w.Header().Add("Location", "http://localhost:9000/")
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
