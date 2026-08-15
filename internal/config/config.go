package config

type Cookies struct {
	CookieStoreKey  string `mapstructure:"cookieStoreKey"`
	CookieEncKey    string `mapstructure:"cookieEnvKey"`
	SessionStoreKey string `mapstructure:"sessionStoreKey"`
	SessionEncKey   string `mapstructure:"sessionEncKey"`
}

type CSRF struct {
	Key string `mapstructure:"key"`
}
type Server struct {
	Address         string          `mapstructure:"address"`
	Cert            string          `mapstructure:"cert"`
	Key             string          `mapstructure:"key"`
	Port            int             `mapstructure:"port"`
	Cookies         Cookies         `mapstructure:"cookies"`
	CSRF            CSRF            `mapstructure:"csrf"`
	TelestoDeployer TelestoDeployer `mapstructure:"telestoDeployer"`
	ExternalSecrets ExternalSecrets `mapstructure:"externalSecrets"`
}

type Storage struct {
	DSN     string `mapstructure:"dsn"`
	Migrate bool   `mapstructure:"migrate"`
}

type Kratos struct {
	InternalEndpoint string `mapstructure:"internalEndpoint"`
	PublicEndpoint   string `mapstructure:"publicEndpoint"`
}

type Auth struct {
	Kratos Kratos `mapstructure:"kratos"`
}

type TelestoDeployer struct {
	Token string `mapstructure:"token"`
}
type ExternalSecrets struct {
	Token string `mapstructure:"token"`
}

type ServeConfig struct {
	Storage Storage `mapstructure:"storage"`
	Server  Server  `mapstructure:"server"`
	Auth    Auth    `mapstructure:"auth"`
}
