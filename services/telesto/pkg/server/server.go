package server

import (
	"context"
	"fmt"
	"net"
	"net/http"

	// "github.com/danielgtaylor/huma/v2"
	// "github.com/danielgtaylor/huma/v2/adapters/humachi"
	// _ "github.com/danielgtaylor/huma/v2/formats/cbor"
	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humachi"
	"github.com/go-chi/chi/v5"
	"github.com/thisisibrahimd/telesto/pkg/config"
	"go.uber.org/fx"
)

func NewHTTPServer(lc fx.Lifecycle, appConfig *config.Config, telestoApi *TelestoAPI) *http.Server {
	srv := &http.Server{Addr: fmt.Sprintf("%s:%d", appConfig.Server.Address, appConfig.Server.Port), Handler: telestoApi.router}
	lc.Append(fx.Hook{
		OnStart: func(ctx context.Context) error {
			ln, err := net.Listen("tcp", srv.Addr)
			if err != nil {
				return err
			}
			fmt.Println("Starting HTTP server at", srv.Addr)
			go srv.Serve(ln)
			return nil
		},
		OnStop: func(ctx context.Context) error {
			return srv.Shutdown(ctx)
		},
	})
	return srv
}

type TelestoAPI struct {
	router *chi.Mux
	Api    huma.API
}

func NewTelestoApi(lc fx.Lifecycle) *TelestoAPI {
	tApi := &TelestoAPI{}

	tApi.router = chi.NewMux()
	tApi.Api = humachi.New(tApi.router, huma.DefaultConfig("telesto", "1.0.0"))
	return tApi

}
