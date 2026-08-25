package private

import "github.com/thisisibrahimd/telesto/internal/server"

type PrivateServerConfig struct {
	Address         string          `mapstructure:"address" json:"address" validate:"required,hostname_port" default:":80"`
	TLS             server.TLS      `mapstructure:"tls" json:"tls,omitempty"`
	TelestoDeployer TelestoDeployer `mapstructure:"telestoDeployer" json:"telestoDeployer"`
	ExternalSecrets ExternalSecrets `mapstructure:"externalSecrets" json:"externalSecrets"`
}

// TelestoDeployer configuration holding bearer token for argo applicationset
type TelestoDeployer struct {
	Token string `mapstructure:"token" json:"token" validate:"required,alphanum,min=32,max=128"`
}

// ExternalSercts config hodling bearer token for external secrets operator to extracts tokens from server
type ExternalSecrets struct {
	Token string `mapstructure:"token" json:"token" validate:"required,alphanum,min=32,max=128"`
}
