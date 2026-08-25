package private

import (
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/thisisibrahimd/telesto/internal/server"
	"github.com/thisisibrahimd/telesto/internal/server/middlewares"
	"github.com/thisisibrahimd/telesto/internal/server/services"
)

type Server struct {
	l      *server.Logger
	server *http.Server
	serve  func() error
}

func (s *Server) Serve() error {
	s.l.Info("starting server", slog.String("address", s.server.Addr))
	return s.serve()
}

func NewServer(cfg *PrivateServerConfig, svcs *services.Services, logger *server.Logger) *Server {
	srv := &Server{
		server: &http.Server{
			Addr: cfg.Address,
		},
		l: logger,
	}

	if cfg.TLS.IsSet() {
		srv.serve = func() error { return srv.server.ListenAndServeTLS(cfg.TLS.Cert, cfg.TLS.Key) }
		srv.l.Info("configured tls")
	} else {
		srv.serve = srv.server.ListenAndServe
	}

	r := chi.NewRouter()
	srv.server.Handler = r

	// register middlewares
	r.Use(middleware.CleanPath)
	r.Use(middleware.RequestID)
	r.Use(logger.Middleware)
	r.Use(middleware.Recoverer)
	r.Use(middleware.StripSlashes)
	telestoDeployerM := middlewares.BearerToken(cfg.TelestoDeployer.Token)
	externalSecretsM := middlewares.BearerToken(cfg.ExternalSecrets.Token)

	// init handlers
	argoHandler := NewArgoHandler(svcs)
	telestoHandler := newTelestoHandler(svcs)

	// register routes
	r.With(telestoDeployerM).Post("/api/v1/getparams.execute", argoHandler.POSTExecuteParams)
	r.With(externalSecretsM).Post("/api/v1/telestos/{id}/tokens", telestoHandler.GetTelestoTokens)

	return srv
}
