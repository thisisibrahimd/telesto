package config

import (
	"errors"
	"fmt"
	"strings"

	"github.com/creasty/defaults"
	"github.com/go-playground/validator/v10"
	"github.com/mdobak/go-xerrors"
	"github.com/stoewer/go-strcase"
)

// ServeConfig configuration for the telesto server
type ServeConfig struct {
	Storage Storage `mapstructure:"storage" json:"storage" `
	Server  Server  `mapstructure:"server" json:"server"`
	Debug   bool    `mapstrucutre:"debug" json:"debug,omitempty" default:"false"`
}

// Storage configuration for the database connection and settings
type Storage struct {
	DSN     string `mapstructure:"dsn" json:"dsn" validate:"required"`
	Migrate bool   `mapstructure:"migrate" json:"migrate,omitempty" default:"true"`
}

// Server configuration for the web and api servers in telesto
type Server struct {
	Public   PublicServer   `mapstructure:"public" json:"public"`
	Internal InternalServer `mapstructure:"internal" json:"internal"`
}

type PublicServer struct {
	Address string  `mapstructure:"address" json:"address" validate:"required,hostname_port" default:":80"`
	TLS     TLS     `mapstrucutre:"tls" json:"tls,omitempty"`
	Cookies Cookies `mapstructure:"cookies" json:"cookies"`
	CSRF    CSRF    `mapstructure:"csrf" json:"csrf"`
	Auth    Auth    `mapstructure:"auth" json:"auth"`
}

type InternalServer struct {
	Address         string          `mapstructure:"address" json:"address" validate:"required,hostname_port" default:":80"`
	TLS             TLS             `mapstrucutre:"tls" json:"tls,omitempty"`
	TelestoDeployer TelestoDeployer `mapstructure:"telestoDeployer" json:"telestoDeployer"`
	ExternalSecrets ExternalSecrets `mapstructure:"externalSecrets" json:"externalSecrets"`
}

type TLS struct {
	Cert string `mapstructure:"cert" json:"cert,omitempty" validate:"required_with=Key,omitempty,filepath,file"`
	Key  string `mapstructure:"key" json:"key,omitempty" validate:"required_with=Cert,omitempty,filepath,file"`
}

type Cookies struct {
	CookieStoreKey  string `mapstructure:"cookieStoreKey" json:"cookieStoreKey" validate:"required,alphanum,min=32,max=128"`
	CookieEncKey    string `mapstructure:"cookieEnvKey" json:"cookieEnvKey" validate:"required,alphanum,min=32,max=128"`
	SessionStoreKey string `mapstructure:"sessionStoreKey" json:"sessionStoreKey" validate:"required,alphanum,min=32,max=128"`
	SessionEncKey   string `mapstructure:"sessionEncKey" json:"sessionEncKey" validate:"required,alphanum,min=32,max=128"`
}

type CSRF struct {
	Key string `mapstructure:"key" json:"key" validate:"required,alphanum,min=32,max=128"`
}

type Auth struct {
	Kratos Kratos `mapstructure:"kratos" json:"kratos"`
}

type Kratos struct {
	InternalEndpoint string `mapstructure:"internalEndpoint" json:"internalEndpoint" validate:"required,url"`
	PublicEndpoint   string `mapstructure:"publicEndpoint" json:"publicEndpoint" validate:"required,url"`
}

type TelestoDeployer struct {
	Token string `mapstructure:"token" json:"token" validate:"required,alphanum,min=32,max=128"`
}

type ExternalSecrets struct {
	Token string `mapstructure:"token" json:"token" validate:"required,alphanum,min=32,max=128"`
}

func Validate(cfg *ServeConfig) error {
	validate := validator.New(validator.WithRequiredStructEnabled())

	if err := validate.Struct(cfg); err != nil {
		var invalidValidationError *validator.InvalidValidationError
		if errors.As(err, &invalidValidationError) {
			panic(err)
		}

		var formattedValidateErrs error

		var validateErrs validator.ValidationErrors
		if errors.As(err, &validateErrs) {
			for _, e := range validateErrs {
				// remove serveconfig. in the keypath, then lowercase the key
				key := strcase.LowerCamelCase(strings.Join(strings.Split(e.Namespace(), ".")[1:], "."))

				errorString := ""
				errorString += fmt.Sprintf("validation rule (%s) failed for %s: ", e.Tag(), key)

				fieldName := strcase.LowerCamelCase(e.Field())
				switch e.Tag() {
				case "required":
					errorString += fmt.Sprintf("%s was not provided", fieldName)
				case "filepath":
					errorString += fmt.Sprintf("unable to find file %s", fieldName)
				case "hostname_port":
					errorString += fmt.Sprintf("%s is not in the format of hostname:port", fieldName)
				case "alphanum":
					errorString += fmt.Sprintf("%s is not alphanumeric (only letters and numbers))", fieldName)
				case "file":
					errorString += fmt.Sprintf("unable to access file %s", fieldName)
				case "url":
					errorString += fmt.Sprintf("%s is not in the format of a url", fieldName)
				case "min":
					errorString += fmt.Sprintf("length of %s must be greater than or equal to %s", fieldName, e.Param())
				case "max":
					errorString += fmt.Sprintf("length of %s must be less than or equal to %s", fieldName, e.Param())
				}

				formattedValidateErrs = xerrors.Append(formattedValidateErrs, xerrors.New(errorString))
			}

			return xerrors.New("error in config", formattedValidateErrs)
		}
	}

	return nil
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
