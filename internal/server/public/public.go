package public

import (
	"io/fs"
	"log/slog"
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/gorilla/schema"
	"github.com/mdobak/go-xerrors"
	ory "github.com/ory/kratos-client-go/v26"
	"github.com/thisisibrahimd/telesto/internal/server"
	"github.com/thisisibrahimd/telesto/internal/server/middlewares"
	"github.com/thisisibrahimd/telesto/internal/server/services"
	"github.com/thisisibrahimd/telesto/internal/server/transport"
	"github.com/thisisibrahimd/telesto/static"
)

type PublicServer struct {
	l      *server.Logger
	server *http.Server
	serve  func() error
}

func (s *PublicServer) Serve() error {
	s.l.Info("starting server", slog.String("address", s.server.Addr))
	return s.serve()
}

func NewServer(cfg *PublicServerConfig, svcs *services.Services, logger *server.Logger) *PublicServer {
	srv := &PublicServer{
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

	router := chi.NewRouter()
	srv.server.Handler = router
	schemaDecoder := schema.NewDecoder()

	// init ory client
	client := &http.Client{}

	// create ca cert pool
	var initialTransport http.RoundTripper
	if cfg.TLS.CACert != "" {
		rootCACertFile, err := os.ReadFile(cfg.TLS.CACert)
		if err != nil {
			panic(xerrors.New("error reading ca cert file", err))
		}
		initialTransport = transport.NewTLSRoundTripper(rootCACertFile)
	} else {
		initialTransport = transport.NewDefaultRoundTripper()
	}

	// set transport
	client.Transport = transport.New().Then(initialTransport)

	oryCfg := &ory.Configuration{
		UserAgent: "telesto-server",
		Servers: ory.ServerConfigurations{
			{
				URL:         cfg.Auth.Kratos.InternalEndpoint,
				Description: "kratos internal endpoint",
			},
		},
		HTTPClient: client,
	}
	oryClient := ory.NewAPIClient(oryCfg)

	// register middlewares
	router.Use(middleware.CleanPath)
	router.Use(middleware.RequestID)
	router.Use(logger.Middleware)
	router.Use(cors.Handler(cors.Options{
		AllowedOrigins: []string{"https://auth.telesto.test", "https://auth-kratos-public.auth"}, // Use this to allow specific origin hosts
		// AllowedOrigins:   []string{"https://*", "http://*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token", "Location", "Cookie"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300, // Maximum value not ignored by any of major browsers
	}))
	router.Use(middleware.Recoverer)
	router.Use(middleware.StripSlashes)
	router.Use(middleware.Heartbeat("/ping"))
	router.Use(middlewares.LoadSession(oryClient))
	protect := middlewares.Protected(oryClient, cfg.Auth.Kratos.PublicEndpoint)

	// static files
	subFs, _ := fs.Sub(static.Dir, ".")
	newFileServer(router, "/static", http.FS(subFs))

	// init handlers
	rootHandler := newRootHandler()
	authHandler := newAuthHandler(cfg.Auth.Kratos.PublicEndpoint, cfg.BaseURL, oryClient)
	consoleHandler := newConsoleHandler()
	telestoHandler := newTelestoHandler(svcs, schemaDecoder)
	tokenHandler := newTokenHandler(svcs, schemaDecoder)

	// register routes
	router.Get("/", http.HandlerFunc(rootHandler.Index))
	router.Get("/login", http.HandlerFunc(authHandler.Login))
	router.Get("/register", http.HandlerFunc(authHandler.Register))
	router.Group(func(r chi.Router) {
		// protected routes
		r.Use(protect)
		// console
		r.Get("/console", http.HandlerFunc(consoleHandler.Index))
		// auth
		r.Get("/logout", http.HandlerFunc(authHandler.Logout))
		// teletos
		r.Get("/telestos", http.HandlerFunc(telestoHandler.GetTelestos))
		r.Get("/telestos/{id}", http.HandlerFunc(telestoHandler.GetTelesto))
		r.Get("/telestos/new", http.HandlerFunc(telestoHandler.NewTelesto))
		r.Post("/telestos/new", http.HandlerFunc(telestoHandler.NewTelestoSubmit))
		r.Get("/telestos/edit/{id}", http.HandlerFunc(telestoHandler.EditTelesto))
		r.Put("/telestos/edit/{id}", http.HandlerFunc(telestoHandler.EditTelestoSubmit))
		r.Delete("/telestos/{id}", http.HandlerFunc(telestoHandler.DeleteTelesto))
		// tokens
		r.Get("/tokens", http.HandlerFunc(tokenHandler.GetTokens))
		r.Get("/tokens/{id}", http.HandlerFunc(tokenHandler.GetToken))
		r.Get("/tokens/new", http.HandlerFunc(tokenHandler.NewToken))
		r.Post("/tokens/new", http.HandlerFunc(tokenHandler.NewTokenSubmit))
		r.Get("/tokens/edit/{id}", http.HandlerFunc(tokenHandler.EditToken))
		r.Put("/tokens/edit/{id}", http.HandlerFunc(tokenHandler.EditTokenSubmit))
		r.Delete("/tokens/{id}", http.HandlerFunc(tokenHandler.DeleteToken))
	})

	return srv
}
