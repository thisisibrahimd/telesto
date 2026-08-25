package config

import (
	"errors"
	"fmt"
	"strings"

	"github.com/creasty/defaults"
	"github.com/go-playground/validator/v10"
	"github.com/mdobak/go-xerrors"
	"github.com/stoewer/go-strcase"
	"github.com/thisisibrahimd/telesto/internal/server/private"
	"github.com/thisisibrahimd/telesto/internal/server/public"
	"github.com/thisisibrahimd/telesto/internal/storage"
	"github.com/thisisibrahimd/telesto/internal/telemetry"
)

// ServeConfig configuration for the telesto server
type ServeConfig struct {
	Storage   storage.StorageConfig     `json:"storage"`
	Server    ServerConfig              `json:"server"`
	Telemetry telemetry.TelemetryConfig `json:"telemetry"`
}

type ServerConfig struct {
	Public  public.PublicServerConfig   `json:"public"`
	Private private.PrivateServerConfig `json:"private"`
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
