package main

import (
	"fmt"

	"github.com/thisisibrahimd/telesto/cmd"
	"github.com/thisisibrahimd/telesto/pkg/config"
)

func main() {
	// set up config information
	configFilePath := ""
	appConfig, err := config.NewConfig()
	if err != nil {
		panic(fmt.Errorf("unable to setup config: %w", err))
	}

	cmd.Execute(configFilePath, appConfig)
}
