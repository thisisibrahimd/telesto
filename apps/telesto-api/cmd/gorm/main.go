package main

import (
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/models"
	"gorm.io/gen"
)

func main() {
	g := gen.NewGenerator(gen.Config{
		OutPath: "./internal/db/query",
		Mode:    gen.WithDefaultQuery,
	})

	g.ApplyBasic(
		models.OtelCol{},
	)

	g.Execute()
}
