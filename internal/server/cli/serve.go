package cli

import (
	"sync"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/thisisibrahimd/telesto/internal/config"
	"github.com/thisisibrahimd/telesto/internal/server"
	"github.com/thisisibrahimd/telesto/internal/server/private"
	"github.com/thisisibrahimd/telesto/internal/server/public"
	"github.com/thisisibrahimd/telesto/internal/server/services"
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
			// l := telemetry.NewLogger()

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

			// l.Info("config initialized", "config", serveViperCfg.ConfigFileUsed())
			return nil
		},
		RunE: func(cmd *cobra.Command, args []string) error {
			// logging
			l := telemetry.NewLogger(serveCfg.Telemetry.Log)

			// storage
			sto := storage.NewStorage(&serveCfg.Storage, storage.NewLogger(l), storage.NewGormLogger(l))

			// init servies
			svcs := services.NewServices(sto)

			// create servers
			pus := public.NewServer(&serveCfg.Server.Public, svcs, server.NewLogger(l, "public"))
			prs := private.NewServer(&serveCfg.Server.Private, svcs, server.NewLogger(l, "private"))

			// run servers
			var wg sync.WaitGroup

			wg.Add(2)
			go pus.Serve()
			go prs.Serve()
			wg.Wait()

			return nil
		},
	}

	cmd.Flags().StringVar(&serveCfgFile, "config", DEFAULT_CONFIG_FILE, "config file")

	return cmd
}
