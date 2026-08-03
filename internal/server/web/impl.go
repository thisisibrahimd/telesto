package web

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"regexp"
	"slices"
	"strings"

	"github.com/gorilla/schema"
	ory "github.com/ory/kratos-client-go/v26"
	"github.com/thisisibrahimd/telesto/internal/server/middlewares"
	"github.com/thisisibrahimd/telesto/internal/storage"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/templates/pages"
	"github.com/thisisibrahimd/telesto/templates/pages/otelcols"
)

var _ WebServerInterface = (*WebServer)(nil)

type WebServerConfig struct {
	OryAPIClient *ory.APIClient
	AuthEndpoint string
	Storage      *storage.Storage
}

type WebServer struct {
	oryClient    *ory.APIClient
	authEndpoint string
	storage      *storage.Storage
	decoder      *schema.Decoder
}

// ExecuteParams implements [WebServerInterface].
func (s *WebServer) ExecuteParams(w http.ResponseWriter, r *http.Request) {
	type PluginInputParams struct {
		// The parameters passed in the ApplicationSet spec.generators.plugin.parameters field
		Parameters map[string]interface{} `json:"parameters"`
	}
	type PluginInput struct {
		ApplicationSetName string            `json:"applicationSetName"`
		Input              PluginInputParams `json:"input"`
	}
	type PluginOutputParams struct {
		// Must be a list of object maps. Each map becomes a set of parameters for a new Application.
		Parameters []map[string]interface{} `json:"parameters"`
	}
	type PluginOutput struct {
		Output PluginOutputParams `json:"output"`
	}
	type GetParamsExecutePostResponse struct {
		Body PluginOutput
	}

	otelcols, err := s.storage.GetOtelcols(r.Context())
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	output := &PluginOutput{
		Output: PluginOutputParams{
			Parameters: []map[string]interface{}{},
		},
	}

	for _, otelcol := range otelcols {
		output.Output.Parameters = append(output.Output.Parameters, map[string]interface{}{
			"otelcol": map[string]string{
				"id":   strings.ToLower(otelcol.ID),
				"name": strings.ToLower(otelcol.Name),
			},
		})
	}

	_ = json.NewEncoder(w).Encode(output)
}

// CreateOtelcolExec implements [WebServerInterface].
func (s *WebServer) CreateOtelcolExec(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	err := r.ParseForm()
	if err != nil {
		return
	}

	var newOtelcol model.Otelcol

	if err := s.decoder.Decode(&newOtelcol, r.Form); err != nil {
		return
	}
	if err := s.storage.CreateOtelcolByUserId(r.Context(), userId, &newOtelcol); err != nil {
		return
	}
	http.Redirect(w, r, "/otelcols/"+newOtelcol.ID, http.StatusSeeOther)
}

// DeleteOtelcol implements [WebServerInterface].
func (s *WebServer) DeleteOtelcol(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	otelcolId := r.PathValue("id")
	if otelcolId == "" {
		return
	}

	if err := s.storage.DeleteOtelcolByUserId(r.Context(), userId, otelcolId); err != nil {
		return
	}

	http.Redirect(w, r, "/otelcols", http.StatusSeeOther)
}

// UpdateOtelcolExec implements [WebServerInterface].
func (s *WebServer) UpdateOtelcolExec(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	otelcolId := r.PathValue("id")
	if otelcolId == "" {
		return
	}
	err := r.ParseForm()
	if err != nil {
		return
	}
	var updatedOtelcol model.Otelcol
	if err := s.decoder.Decode(&updatedOtelcol, r.Form); err != nil {
		return
	}

	if err := s.storage.UpdateOtelcolByUserId(r.Context(), userId, otelcolId, &updatedOtelcol); err != nil {
		return
	}
	http.Redirect(w, r, "/otelcols/"+otelcolId, http.StatusSeeOther)
}

// CreateOtelcol implements [WebServerInterface].
func (s *WebServer) CreateOtelcol(w http.ResponseWriter, r *http.Request) {
	otelcols.New().Render(r.Context(), w)
}

// GetOtelcol implements [WebServerInterface].
func (s *WebServer) GetOtelcol(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	otelcolId := r.PathValue("id")
	if otelcolId == "" {
		return
	}

	otelcol, _ := s.storage.GetOtelcolByUserId(r.Context(), userId, otelcolId)
	otelcols.Show(*convertOtelcol(otelcol)).Render(r.Context(), w)
}

// ListOtelcols implements [WebServerInterface].
func (s *WebServer) ListOtelcols(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	userOtelcols, err := s.storage.GetOtelcolsByUserId(r.Context(), userId)
	if err != nil {
		slog.Error("", slog.Any("error", err))
	}

	otelcolsModels := make([]*otelcols.OtelcolModel, 0)
	for _, oc := range userOtelcols {
		otelcolsModels = append(otelcolsModels, convertOtelcol(oc))
	}

	otelcols.Index(otelcols.OtelcolsViewModel{Otelcols: otelcolsModels}).Render(r.Context(), w)
}

// UpdateOtelcol implements [WebServerInterface].
func (s *WebServer) UpdateOtelcol(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	otelcolId := r.PathValue("id")
	if otelcolId == "" {
		return
	}
	otelcol, _ := s.storage.GetOtelcolByUserId(r.Context(), userId, otelcolId)

	otelcols.Edit(*convertOtelcol(otelcol)).Render(r.Context(), w)
}

func convertOtelcol(o *model.Otelcol) *otelcols.OtelcolModel {
	return &otelcols.OtelcolModel{
		Id:   o.ID,
		Name: o.Name,
	}
}

// Index implements [WebServerInterface].
func (s *WebServer) Index(w http.ResponseWriter, r *http.Request) {
	pages.Index().Render(r.Context(), w)
}

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

func NewWebServer(cfg *WebServerConfig) WebServerInterface {
	s := &WebServer{}

	s.oryClient = cfg.OryAPIClient
	s.storage = cfg.Storage
	s.decoder = schema.NewDecoder()
	s.authEndpoint = cfg.AuthEndpoint

	return s
}
