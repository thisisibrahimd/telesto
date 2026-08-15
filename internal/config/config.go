package config

import (
	"github.com/creasty/defaults"
	"github.com/go-playground/validator/v10"
)

// ServeConfig configuration for the telesto server
type ServeConfig struct {
	Storage Storage `mapstructure:"storage" json:"storage" `
	Server  Server  `mapstructure:"server" json:"server"`
}

// Storage configuration for the database connection and settings
type Storage struct {
	DSN     string `mapstructure:"dsn" json:"dsn" validate:"required"`
	Migrate bool   `mapstructure:"migrate" json:"migrate" default:"true"`
}

// Server configuration for the web and api servers in telesto
type Server struct {
	Public   PublicServer   `mapstructure:"public" json:"public"`
	Internal InternalServer `mapstructure:"internal" json:"internal"`
}

type PublicServer struct {
	Address string  `mapstructure:"address" json:"address" validate:"required,hostname_port" default:":80"`
	TLS     TLS     `mapstrucutre:"tls" json:"tls"`
	Cookies Cookies `mapstructure:"cookies" json:"cookies"`
	CSRF    CSRF    `mapstructure:"csrf" json:"csrf"`
	Auth    Auth    `mapstructure:"auth" json:"auth"`
}

type InternalServer struct {
	Address         string          `mapstructure:"address" json:"address" validate:"required,hostname_port" default:":80"`
	TLS             TLS             `mapstrucutre:"tls" json:"tls"`
	TelestoDeployer TelestoDeployer `mapstructure:"telestoDeployer" json:"telestoDeployer"`
	ExternalSecrets ExternalSecrets `mapstructure:"externalSecrets" json:"externalSecrets"`
}

type TLS struct {
	Cert TLSResource `mapstructure:"cert" json:"cert" validate:"required_with=Key,file"`
	Key  TLSResource `mapstructure:"key" json:"key" validate:"required_with=Cert,file"`
}

type TLSResource struct {
	Path   string `mapstructure:"path" json:"path,omitempty" validate:"file,required_without=Base64"`
	Base64 string `mapstructure:"base64" json:"base64,omitempty" validate:"base64,required_without=Path" `
}

type Cookies struct {
	CookieStoreKey  string `mapstructure:"cookieStoreKey" json:"cookieStoreKey" validate:"alphanum,required,min=32,max=128"`
	CookieEncKey    string `mapstructure:"cookieEnvKey" json:"cookieEnvKey" validate:"alphanum,required,min=32,max=128"`
	SessionStoreKey string `mapstructure:"sessionStoreKey" json:"sessionStoreKey" validate:"alphanum,required,min=32,max=128"`
	SessionEncKey   string `mapstructure:"sessionEncKey" json:"sessionEncKey" validate:"alphanum,required,min=32,max=128"`
}

type CSRF struct {
	Key string `mapstructure:"key" json:"key" validate:"alphanum,required,min=32,max=128"`
}

type Auth struct {
	Kratos Kratos `mapstructure:"kratos" json:"kratos"`
}

type Kratos struct {
	InternalEndpoint string `mapstructure:"internalEndpoint" json:"internalEndpoint" validate:"url,required"`
	PublicEndpoint   string `mapstructure:"publicEndpoint" json:"publicEndpoint" validate:"url,required"`
}

type TelestoDeployer struct {
	Token string `mapstructure:"token" json:"token" validate:"alphanum,required,min=32,max=128"`
}

type ExternalSecrets struct {
	Token string `mapstructure:"token" json:"token" validate:"alphanum,required,min=32,max=128"`
}

func Validate(cfg *ServeConfig) error {
	validate := validator.New(validator.WithRequiredStructEnabled())
	return validate.Struct(cfg)
}

func setDefaults(cfg *ServeConfig) {
	if err := defaults.Set(cfg); err != nil {
		panic(err)
	}
}

func NewServeConfig() *ServeConfig {
	serveCfg := &ServeConfig{}
	setDefaults(serveCfg)
	return serveCfg
}
