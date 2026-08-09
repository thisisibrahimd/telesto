package web

import (
	"net/http"

	"github.com/gorilla/schema"
	ory "github.com/ory/kratos-client-go/v26"
	"github.com/thisisibrahimd/telesto/internal/storage"
	"github.com/thisisibrahimd/telesto/templates/pages"
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

// Index implements [WebServerInterface].
func (s *WebServer) Index(w http.ResponseWriter, r *http.Request) {
	pages.Index().Render(r.Context(), w)
}

func (s *WebServer) Console(w http.ResponseWriter, r *http.Request) {
	pages.Console().Render(r.Context(), w)
}

func NewWebServer(cfg *WebServerConfig) WebServerInterface {
	s := &WebServer{}

	s.oryClient = cfg.OryAPIClient
	s.storage = cfg.Storage
	s.decoder = schema.NewDecoder()
	s.authEndpoint = cfg.AuthEndpoint

	return s
}
