package cli

import (
	"errors"
	"log/slog"
	"strings"

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
	var serveCfg *config.ServeConfig

	cmd := &cobra.Command{
		Use: "serve",
		PreRunE: func(cmd *cobra.Command, args []string) error {
			// logging
			l := telemetry.NewLogger()

			serveViperCfg.SetEnvPrefix("tl")
			serveViperCfg.SetEnvKeyReplacer(strings.NewReplacer(".", "*", "-", "*"))
			serveViperCfg.AllowEmptyEnv(true)

			// handle the configuration file
			if serveCfgFile != "" {
				serveViperCfg.SetConfigFile(serveCfgFile)
			} else {
				serveViperCfg.AddConfigPath(".")
				serveViperCfg.SetConfigName("telesto")
				serveViperCfg.SetConfigType("json")
			}

			// read the config file
			if err := serveViperCfg.ReadInConfig(); err != nil {
				var configFileNotFoundError viper.ConfigFileNotFoundError
				if !errors.As(err, &configFileNotFoundError) {
					return err
				}
			}
			if err := serveViperCfg.Unmarshal(&serveCfg); err != nil {
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
						URL:         serveCfg.Auth.Kratos.InternalEndpoint,
						Description: "kratos public endpoint",
					},
				},
			}
			oryClient := ory.NewAPIClient(oryCfg)

			// session keys
			// srvKeyStore := server.BadKeyStore()

			// server
			srvCfg := &server.Config{
				Address: serveCfg.Server.Address,
				Logger:  server.NewServerLogger(l),
				// KeyStore:        srvKeyStore,
				Storage:              sto,
				OryKratosClient:      oryClient,
				KratosPublicEndpoint: serveCfg.Auth.Kratos.PublicEndpoint,
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

	// cmd.Flags().StringVar(&opts.Address, "address", "localhost:9000", "server address")
	// cmd.Flags().StringVar(&opts.LogLevel, "log-level", "info", "log level")
	// cmd.Flags().StringVar(&opts.DSN, "dsn", "http://localhost:4001", "dsn")
	// cmd.Flags().StringVar(&opts.KratosInternalPublicEndpoint, "kratos-internal-public-endpoint", "http://localhost:4433", "kratos internal public endpoint")
	// cmd.Flags().StringVar(&opts.KratosPublicEndpoint, "kratos-public-endpoint", "http://localhost:4433", "kratos public endpoint")
	// cmd.Flags().BoolVar(&opts.Migrate, "migrate", false, "migrate db")
	// cmd.Flags().StringVar(&opts.CookieStoreKey, "cookie-store-key", "", "cookie store key")
	// cmd.Flags().StringVar(&opts.CookieEncKey, "cookie-env-key", "", "cookie env key")
	// cmd.Flags().StringVar(&opts.SessionStoreKey, "session-store-key", "", "session store key")
	// cmd.Flags().StringVar(&opts.SessionEncKey, "session-enc-key", "", "session env key")
	// cmd.Flags().StringVar(&opts.CsrfKey, "csrf-key", "", "csrf key")

	cmd.Flags().StringVar(&serveCfgFile, "config", "./telesto.json", "config file")

	return cmd
}
