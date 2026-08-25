package cli

import (
	"errors"
	"strings"

	"github.com/mdobak/go-xerrors"
	"github.com/spf13/viper"
	"github.com/thisisibrahimd/telesto/internal/config"
)

const DEFAULT_CONFIG_FILE = "./telesto.json"

func loadViperConfig(v *viper.Viper, loadEnv bool, cfg *config.ServeConfig, cfgFile string) error {
	// setup envs lookup
	if loadEnv {
		v.SetEnvPrefix("tl")
		v.SetEnvKeyReplacer(strings.NewReplacer(".", "*", "-", "*"))
		v.AllowEmptyEnv(true)
	}

	// set default config file path
	if cfgFile != "" {
		v.SetConfigFile(cfgFile)
	} else {
		v.SetConfigFile(DEFAULT_CONFIG_FILE)
	}

	// read config file
	if err := v.ReadInConfig(); err != nil {
		var configFileNotFoundError viper.ConfigFileNotFoundError
		if !errors.As(err, &configFileNotFoundError) {
			return xerrors.New("error finding file", err)
		}
	}
	// slog.Debug("successfully read config file", slog.String("config", cfgFile))

	if err := v.Unmarshal(cfg); err != nil {
		return xerrors.New("error parsing config")
	}
	// slog.Debug("successfully parse config file", slog.String("config", cfgFile))

	return nil
}
