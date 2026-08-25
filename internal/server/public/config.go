package public

import "github.com/thisisibrahimd/telesto/internal/server"

type PublicServerConfig struct {
	Address string     `mapstructure:"address" json:"address" validate:"required,hostname_port" default:":80"`
	TLS     server.TLS `mapstructure:"tls" json:"tls,omitempty"`
	Cookies Cookies    `mapstructure:"cookies" json:"cookies"`
	CSRF    CSRF       `mapstructure:"csrf" json:"csrf"`
	Auth    Auth       `mapstructure:"auth" json:"auth"`
	BaseURL string     `mapstructure:"baseUrl" json:"baseUrl"`
	// OryAPIClient  *ory.APIClient
	// AuthEndpoint  string
	// ServerBaseURL string
}

type Cors struct {
	AllowedOrgins    []string `mapstructure:"allowedOrigins" json:"allowedOrigins"`
	AllowedMethods   []string `mapstructure:"allowedMethods" json:"allowedMethods"`
	AllowedHeaders   []string `mapstructure:"allowedHeaders" json:"allowedHeaders"`
	ExposedHeaders   []string `mapstructure:"exposedHeaders" json:"exposedHeaders"`
	AllowCredentials bool
	MaxAge           int
}

type Cookies struct {
	CookieStoreKey  string `mapstructure:"cookieStoreKey" json:"cookieStoreKey" validate:"required,alphanum,min=32,max=128"`
	CookieEncKey    string `mapstructure:"cookieEncKey" json:"cookieEncKey" validate:"required,alphanum,min=32,max=128"`
	SessionStoreKey string `mapstructure:"sessionStoreKey" json:"sessionStoreKey" validate:"required,alphanum,min=32,max=128"`
	SessionEncKey   string `mapstructure:"sessionEncKey" json:"sessionEncKey" validate:"required,alphanum,min=32,max=128"`
}

type CSRF struct {
	Key string `mapstructure:"key" json:"key" validate:"required,alphanum,min=32,max=128"`
}
type Auth struct {
	Kratos Kratos `mapstructure:"kratos" json:"kratos"`
}

// Kratos endpoints of ORY Kratos self-hosted
type Kratos struct {
	InternalEndpoint string `mapstructure:"internalEndpoint" json:"internalEndpoint" validate:"required,url"`
	PublicEndpoint   string `mapstructure:"publicEndpoint" json:"publicEndpoint" validate:"required,url"`
}
