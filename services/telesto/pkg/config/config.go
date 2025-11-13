package config

import (
	"github.com/creasty/defaults"
	"go.uber.org/fx"
)

type Config struct {
	Server struct {
		Port    int    `default:"8080"`
		Address string `default:"127.0.0.1"`
	}
}

func NewConfig() (*Config, error) {
	c := &Config{}
	err := defaults.Set(c)
	if err != nil {
		return nil, err
	}
	return c, err
}

func NewConfigDI(appConfig *Config) func(lc fx.Lifecycle) *Config {
	return func(lc fx.Lifecycle) *Config {
		return appConfig
	}
}
