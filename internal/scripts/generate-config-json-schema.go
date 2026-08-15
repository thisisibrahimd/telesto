//go:build tools

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"path"

	"github.com/invopop/jsonschema"
	"github.com/stoewer/go-strcase"
	"github.com/thisisibrahimd/telesto/internal/config"
)

func main() {
	slog.Info("generating cnfig jsonschema")
	var output string
	flag.StringVar(&output, "output", "", "output path of generated jsonschema")

	flag.Parse()
	slog.Info("parsed flags")

	r := new(jsonschema.Reflector)
	r.KeyNamer = strcase.LowerCamelCase // from package github.com/stoewer/go-strcase
	// TODO: get go comments working
	if err := r.AddGoComments("github.com/invopop/jsonschema", "./"); err != nil {
		panic(err)
	}

	slog.Info("set casing to lower camel case")

	configSchema := r.Reflect(&config.ServeConfig{})
	slog.Info("generated jsonschema")

	configSchemaBytes, err := json.MarshalIndent(configSchema, "", "  ")
	if err != nil {
		slog.Info("failed to stringfy the jsonschema for writing")
		panic(err)
	}

	if err := os.WriteFile(output, configSchemaBytes, 0666); err != nil {
		panic(err)
	}
	cwd, _ := os.Getwd()
	fullOutputPath := path.Join(cwd, output)
	slog.Info(fmt.Sprintf("written generated jsonschema to %s", fullOutputPath))
}
