package cli

import (
	"log/slog"

	"github.com/mdobak/go-xerrors"
	ory "github.com/ory/kratos-client-go/v26"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/thisisibrahimd/telesto/internal/config"
	"github.com/thisisibrahimd/telesto/internal/server"
	"github.com/thisisibrahimd/telesto/internal/storage"
	"github.com/thisisibrahimd/telesto/internal/telemetry"
)

func NewServeCommand() *cobra.Command {
	var serveCfgFile string
	serveViperCfg := viper.New()
	serveCfg := config.NewServeConfig()

	cmd := &cobra.Command{
		Use: "serve",
		PreRunE: func(cmd *cobra.Command, args []string) error {
			// logging
			l := telemetry.NewLogger()

			if err := loadViperConfig(serveViperCfg, true, serveCfg, serveCfgFile); err != nil {
				return err
			}

			// validate the config
			if err := config.Validate(serveCfg); err != nil {
				return err
			}

			// flags
			err := serveViperCfg.BindPFlags(cmd.Flags())
			if err != nil {
				return err
			}

			l.Info("config initialized", "config", serveViperCfg.ConfigFileUsed())
			return nil
		},
		RunE: func(cmd *cobra.Command, args []string) error {
			// logging
			l := telemetry.NewLogger()

			// storage
			stoCfg := storage.DefaultConfig()
			stoCfg.Migrate = serveCfg.Storage.Migrate
			stoCfg.DSN = serveCfg.Storage.DSN
			stoCfg.Type = storage.DB_TYPE_POSTGRES
			sto, err := storage.NewStorage(stoCfg)
			if err != nil {
				return xerrors.New("failed to create storage", err)
			}

			// auth
			oryCfg := &ory.Configuration{
				UserAgent: "teleesto-server",
				Servers: ory.ServerConfigurations{
					{
						URL:         serveCfg.Server.Public.Auth.Kratos.InternalEndpoint,
						Description: "kratos public endpoint",
					},
				},
			}
			oryClient := ory.NewAPIClient(oryCfg)

			// session keys
			// srvKeyStore := &server.KeyStore{
			// 	CookieStoreKey:  []byte{},
			// 	CookieEncKey:    []byte{},
			// 	SessionStoreKey: []byte{},
			// 	SessionEncKey:   []byte{},
			// 	CsrfKey:         []byte{},
			// }

			// server
			srvCfg := &server.Config{
				Address: serveCfg.Server.Public.Address,
				Logger:  server.NewServerLogger(l),
				// KeyStore:        srvKeyStore,
				Storage:              sto,
				OryKratosClient:      oryClient,
				KratosPublicEndpoint: serveCfg.Server.Public.Auth.Kratos.PublicEndpoint,
				TelestoDeployer:      serveCfg.Server.Internal.TelestoDeployer,
				ExternalSecrets:      serveCfg.Server.Internal.ExternalSecrets,
			}
			srv, err := server.NewServer(srvCfg)
			if err != nil {
				return xerrors.New("failed to create server", err)
			}

			slog.Info("starting server")
			if serveCfg.Server.Public.TLS.Cert != "" && serveCfg.Server.Public.TLS.Key != "" {
				if err := srv.ListenAndServeTLS(serveCfg.Server.Public.TLS.Cert, serveCfg.Server.Public.TLS.Key); err != nil {
					slog.Error("failed to serve tls server", slog.Any("error", err))
				}
			} else {
				if err := srv.ListenAndServe(); err != nil {
					slog.Error("failed to serve server", slog.Any("error", err))
				}
			}
			return nil
		},
	}

	cmd.Flags().StringVar(&serveCfgFile, "config", DEFAULT_CONFIG_FILE, "config file")

	return cmd
}
