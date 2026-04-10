//go:build tools

package main

import (
	"log/slog"

	ory "github.com/ory/kratos-client-go/v26"
	"github.com/thisisibrahimd/telesto/internal/storage"
	"github.com/thisisibrahimd/telesto/internal/storage/seed"
	"github.com/thisisibrahimd/telesto/internal/telemetry"
)

func main() {
	l := telemetry.NewLogger()
	sto, _ := storage.NewStorage(storage.WithDSN("http://localhost:4001"), storage.WithLogger(l))

	oryCfg := &ory.Configuration{
		UserAgent: "teleesto-server",
		Servers: ory.ServerConfigurations{
			{
				URL: "http://localhost:4434",
			},
		},
	}
	oryClient := ory.NewAPIClient(oryCfg)
	err := seed.SeedSenario1(sto, oryClient)
	if err != nil {
		l.Logger.Error("failed to seed", slog.Any("errors", err))
	}

	l.Logger.Info("seeded db")
}
