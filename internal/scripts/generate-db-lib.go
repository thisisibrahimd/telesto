//go:build tools

package main

import (
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"gorm.io/gen"
)

func main() {
	g := gen.NewGenerator(gen.Config{
		OutPath: ".",
		Mode:    gen.WithDefaultQuery,
	})

	g.ApplyBasic(
		&model.Otelcol{},
	)

	g.Execute()
}
