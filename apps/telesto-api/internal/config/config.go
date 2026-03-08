package config

import (
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

type Config struct {
	Host string `mapstructure:"host" json:"host" usage:"server port"`
	Port int    `mapstructure:"port" json:"port" usage:"server port"`

	Database struct {
		SQLite struct {
			File string `mapstructure:"file" json:"file"`
		}
	}
}

func (c *Config) SetFlags(cmd *cobra.Command, v *viper.Viper) {
	cmd.Flags().StringVar(&c.Host, "host", "localhost", "Server host (valid values: localhost)")
	cmd.Flags().IntVar(&c.Port, "port", 3000, "HTTP port (overrides host HTTP port specified in service design)")

	cmd.Flags().StringVar(&c.Database.SQLite.File, "database.sqlite.file", "", "")

	v.BindPFlag("host", cmd.Flags().Lookup("host"))
	v.BindPFlag("port", cmd.Flags().Lookup("port"))
	v.BindPFlag("database.sqlite.file", cmd.Flags().Lookup("database.sqlite.file"))
}
