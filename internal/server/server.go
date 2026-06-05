package server

import (
	"io/fs"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/gorilla/sessions"
	ory "github.com/ory/kratos-client-go/v26"
	"github.com/thisisibrahimd/telesto/internal/server/middlewares"
	"github.com/thisisibrahimd/telesto/internal/server/web"
	"github.com/thisisibrahimd/telesto/internal/storage"
	"github.com/thisisibrahimd/telesto/static"
)

type Config struct {
	Address string
	Logger  *Logger
	// KeyStore        *KeyStore
	Storage              *storage.Storage
	OryKratosClient      *ory.APIClient
	KratosPublicEndpoint string
}

type Server struct {
	config      *Config
	router      *chi.Mux
	cookieStore *sessions.CookieStore
}

func (s *Server) ListenAndServe() error {
	return http.ListenAndServe(s.config.Address, s.router)
}

func NewServer(cfg *Config) (*Server, error) {
	srv := &Server{
		config: cfg,
	}

	// create router
	router := chi.NewRouter()
	srv.router = router

	// register middlewares
	router.Use(middleware.RequestID)
	router.Use(srv.config.Logger.Middleware)
	router.Use(cors.Handler(cors.Options{
		AllowedOrigins: []string{"http://auth.telesto.test"}, // Use this to allow specific origin hosts
		// AllowedOrigins:   []string{"https://*", "http://*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token", "Location", "Cookie"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300, // Maximum value not ignored by any of major browsers
	}))
	router.Use(middleware.Recoverer)
	router.Use(middlewares.LoadSession(srv.config.OryKratosClient))
	protect := middlewares.Protected(srv.config.OryKratosClient, srv.config.KratosPublicEndpoint)

	// static files
	subFs, _ := fs.Sub(static.Dir, ".")
	FileServer(router, "/static", http.FS(subFs))

	// api server impl
	// strictServerConfig := api.ServerConfig{
	// 	Storage: srv.storage,
	// 	Logger:  srv.logger.Logger,
	// }
	// strictServerApi, err := api.NewStrictServer(&strictServerConfig)
	// if err != nil {
	// 	return nil, xerrors.New("failed to create api handlers")
	// }
	// serverApi := api.NewStrictHandler(strictServerApi, nil)
	// serverApiHandler := api.HandlerFromMux(serverApi, router)

	// // api handler
	// router.Handle("/api", http.StripPrefix("/api/", serverApiHandler))

	// web server
	webServer := web.NewWebServer(&web.WebServerConfig{OryAPIClient: srv.config.OryKratosClient, Storage: srv.config.Storage, AuthEndpoint: srv.config.KratosPublicEndpoint})
	web.Handler(router, protect, webServer)

	return srv, nil
}

// FileServer conveniently sets up a http.FileServer handler to serve
// static files from a http.FileSystem.
func FileServer(r chi.Router, path string, root http.FileSystem) {
	if strings.ContainsAny(path, "{}*") {
		panic("FileServer does not permit any URL parameters.")
	}

	if path != "/" && path[len(path)-1] != '/' {
		r.Get(path, http.RedirectHandler(path+"/", 301).ServeHTTP)
		path += "/"
	}
	path += "*"

	r.Get(path, func(w http.ResponseWriter, r *http.Request) {
		rctx := chi.RouteContext(r.Context())
		pathPrefix := strings.TrimSuffix(rctx.RoutePattern(), "/*")
		fs := http.StripPrefix(pathPrefix, http.FileServer(root))
		fs.ServeHTTP(w, r)
	})
}
