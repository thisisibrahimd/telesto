package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/thisisibrahimd/telesto/pkg/config"
)

func Execute(configFilePath string, appConfig *config.Config) {
	err := GetRootCmd(configFilePath, appConfig).Execute()
	if err != nil {
		os.Exit(1)
	}
}

func GetRootCmd(configFilePath string, appConfig *config.Config) *cobra.Command {
	rootCmd := &cobra.Command{
		Use: "telesto",
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			loadConfig(configFilePath, appConfig)
		},
	}

	// route commands
	rootCmd.AddCommand(GetServeCmd(appConfig))

	rootCmd.PersistentFlags().StringVarP(&configFilePath, "config", "c", "", "config file for telesto")
	err := rootCmd.MarkPersistentFlagRequired("config")
	if err != nil {
		panic(fmt.Errorf("config flag not set: %w", err))
	}

	return rootCmd
}

func loadConfig(cfgFile string, appConfig *config.Config) {
	var vConfig = viper.New()
	vConfig.SetConfigFile(cfgFile)

	err := vConfig.ReadInConfig()
	if err != nil {
		panic(fmt.Errorf("fatal error config file: %w", err))
	}

	err = vConfig.Unmarshal(&appConfig)
	if err != nil {
		panic(fmt.Errorf("unable to decode into struct: %w", err))
	}
}
