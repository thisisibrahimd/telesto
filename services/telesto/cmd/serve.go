package cmd

import (
	"net/http"

	"github.com/spf13/cobra"
	"github.com/thisisibrahimd/telesto/pkg/config"
	"github.com/thisisibrahimd/telesto/pkg/server"
	"github.com/thisisibrahimd/telesto/pkg/server/routes"
	"go.uber.org/fx"
)

func GetServeCmd(appConfig *config.Config) *cobra.Command {
	serveCmd := &cobra.Command{
		Use: "serve",
		Run: executeServeCmd(appConfig),
	}
	return serveCmd
}

func executeServeCmd(appConfig *config.Config) func(cmd *cobra.Command, args []string) {
	return func(cmd *cobra.Command, args []string) {
		fx.New(
			fx.Provide(
				config.NewConfigDI(appConfig),
				server.NewTelestoApi,
				server.NewHTTPServer,
			),
			fx.Invoke(
				routes.NewGreetingHandler,
				// server.NewEchoHandler,
			),
			fx.Invoke(func(*http.Server) {}),
		).Run()
	}
}
