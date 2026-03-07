package config

import (
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

type Config struct {
	Host   string `mapstructure:"host" json:"host" usage:"server port"`
	Domain string `mapstructure:"domain" json:"domain" usage:"server port"`
	Port   int    `mapstructure:"port" json:"port" usage:"server port"`

	Secure   bool `mapstructure:"secure" json:"secure" usage:"server port"`
	Debug    bool `mapstructure:"debug" json:"debug" usage:"server port"`
	Database struct {
		SQLite struct {
			File string `mapstructure:"file" json:"file"`
		}
	}
}

func (c *Config) SetFlags(cmd *cobra.Command, v *viper.Viper) {
	cmd.Flags().StringVar(&c.Host, "host", "localhost", "Server host (valid values: localhost)")
	cmd.Flags().StringVar(&c.Domain, "domain", "", "Host domain name (overrides host domain specified in service design)")
	cmd.Flags().IntVar(&c.Port, "port", 3000, "HTTP port (overrides host HTTP port specified in service design)")
	cmd.Flags().BoolVar(&c.Secure, "secure", false, "Use secure scheme (https or grpcs)")
	cmd.Flags().BoolVar(&c.Debug, "debug", false, "Log request and response bodies")

	cmd.Flags().StringVar(&c.Database.SQLite.File, "database.sqlite.file", "", "")

	v.BindPFlag("host", cmd.Flags().Lookup("host"))
	v.BindPFlag("domain", cmd.Flags().Lookup("domain"))
	v.BindPFlag("port", cmd.Flags().Lookup("port"))
	v.BindPFlag("secure", cmd.Flags().Lookup("secure"))
	v.BindPFlag("debug", cmd.Flags().Lookup("debug"))
	v.BindPFlag("database.sqlite.file", cmd.Flags().Lookup("database.sqlite.file"))
}
