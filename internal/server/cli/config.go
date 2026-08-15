package cli

import (
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/thisisibrahimd/telesto/internal/config"
)

func NewConfigCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "config",
		Short: "config management",
	}

	cmd.AddCommand(NewConfigValidateCommand())
	return cmd
}

func NewConfigValidateCommand() *cobra.Command {
	var serveCfgFile string
	serveViperCfg := viper.New()
	serveCfg := config.NewServeConfig()

	cmd := &cobra.Command{
		Use:   "validate",
		Short: "validate server config",
		RunE: func(cmd *cobra.Command, args []string) error {
			// load config file into viper & struct
			if err := loadViperConfig(serveViperCfg, false, serveCfg, serveCfgFile); err != nil {
				return err
			}

			// validate the config
			if err := config.Validate(serveCfg); err != nil {
				return err
			}

			return nil
		},
	}

	cmd.Flags().StringVar(&serveCfgFile, "config", DEFAULT_CONFIG_FILE, "config file")

	return cmd
}
