package cli

import (
	"log/slog"

	"github.com/mdobak/go-xerrors"
	ory "github.com/ory/kratos-client-go/v26"
	"github.com/spf13/cobra"
	"github.com/thisisibrahimd/telesto/internal/server"
	"github.com/thisisibrahimd/telesto/internal/storage"
	"github.com/thisisibrahimd/telesto/internal/telemetry"
)

type ServeOptions struct {
	Address              string
	LogLevel             string `json:"log-level"`
	DSN                  string `json:"dsn"`
	KratosPublicEndpoint string `json:"kratos-public-endpoint"`
	KratosAdminEndpoint  string `json:"kratos-admin-endpoint"`
	Migrate              bool
	InitialUsername      string
	InitialPassword      string
	CookieStoreKey       string
	CookieEncKey         string
	SessionStoreKey      string
	SessionEncKey        string
	CsrfKey              string
}

func NewServeCommand() *cobra.Command {
	opts := ServeOptions{}

	cmd := &cobra.Command{
		Use: "serve",
		// PreRunE: func(cmd *cobra.Command, args []string) error {
		// 	// validate initial user creds

		// 	initialUsername := os.Getenv("TELESTO_INITIAL_USERNAME")
		// 	initialPassword := os.Getenv("TELESTO_INITIAL_PASSWORD")

		// 	if initialUsername == "" && initialPassword == "" {
		// 		return nil
		// 	} else if initialPassword == "" {
		// 		return xerrors.New("TELESTO_INITIAL_PASSWORD env var must not be empty if TELESTO_INITIAL_USERNAME is supplied")
		// 	} else if initialUsername == "" {
		// 		return xerrors.New("TELESTO_INITIAL_USERNAME env var must not be empty if TELESTO_INITIAL_PASSWORD is supplied")
		// 	}

		// 	opts.InitialUsername = initialUsername
		// 	opts.InitialPassword = initialPassword

		// 	return nil
		// },
		RunE: func(cmd *cobra.Command, args []string) error {

			// logging
			l := telemetry.NewLogger()

			// storage
			stoCfg := storage.DefaultConfig()
			stoCfg.Migrate = opts.Migrate
			stoCfg.DSN = opts.DSN
			sto, err := storage.NewStorage(stoCfg)
			if err != nil {
				return xerrors.New("failed to create storage", err)
			}

			// auth
			oryCfg := &ory.Configuration{
				UserAgent: "teleesto-server",
				Servers: ory.ServerConfigurations{
					{
						URL: opts.KratosAdminEndpoint,
					},
				},
			}
			oryClient := ory.NewAPIClient(oryCfg)

			// session keys
			// srvKeyStore := server.BadKeyStore()

			// server
			srvCfg := &server.Config{
				Address: opts.Address,
				Logger:  server.NewServerLogger(l),
				// KeyStore:        srvKeyStore,
				Storage:         sto,
				OryKratosClient: oryClient,
			}
			srv, err := server.NewServer(srvCfg)
			if err != nil {
				return xerrors.New("failed to create server", err)
			}

			slog.Info("starting server")
			if err := srv.ListenAndServe(); err != nil {
				slog.Error("hello", "eerr", err)

			}
			return nil
		},
	}

	cmd.Flags().StringVar(&opts.Address, "address", "localhost:9000", "server address")
	cmd.Flags().StringVar(&opts.LogLevel, "log-level", "info", "log level")
	cmd.Flags().StringVar(&opts.DSN, "dsn", "http://localhost:4001", "dsn")
	cmd.Flags().StringVar(&opts.KratosPublicEndpoint, "kratos-public-endpoint", "http://localhost:4433", "kratos public endpoint")
	cmd.Flags().StringVar(&opts.KratosAdminEndpoint, "kratos-admin-endpoint", "http://localhost:4434", "kratos admin endpoint")
	cmd.Flags().BoolVar(&opts.Migrate, "migrate", false, "migrate db")
	cmd.Flags().StringVar(&opts.CookieStoreKey, "cookie-store-key", "", "cookie store key")
	cmd.Flags().StringVar(&opts.CookieEncKey, "cookie-env-key", "", "cookie env key")
	cmd.Flags().StringVar(&opts.SessionStoreKey, "session-store-key", "", "session store key")
	cmd.Flags().StringVar(&opts.SessionEncKey, "session-enc-key", "", "session env key")
	cmd.Flags().StringVar(&opts.CsrfKey, "csrf-key", "", "csrf key")

	return cmd
}
