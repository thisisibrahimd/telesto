package main

import (
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	_ "github.com/thisisibrahimd/telesto-pb/internal/pocketbase/migrations"
)

// argo cd plugin stuff
// Define the expected input from the ApplicationSet controller
type PluginInput struct {
	ApplicationSetName string            `json:"applicationSetName"`
	Input              PluginInputParams `json:"input"`
}

type PluginInputParams struct {
	// The parameters passed in the ApplicationSet spec.generators.plugin.parameters field
	Parameters map[string]interface{} `json:"parameters"`
}

// Define the required output structure
type PluginOutput struct {
	Output PluginOutputParams `json:"output"`
}

type PluginOutputParams struct {
	// Must be a list of object maps. Each map becomes a set of parameters for a new Application.
	Parameters []map[string]interface{} `json:"parameters"`
}

// end of argo cd support

func main() {
	app := pocketbase.New()

	// loosely check if it was executed using "go run"
	isGoRun := strings.HasPrefix(os.Args[0], os.TempDir())

	// support migration
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		// enable auto creation of migration files when making collection changes in the Dashboard
		// (the isGoRun check is to enable it only during development)
		Automigrate: isGoRun,
	})

	// support argocd plugin generator
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		// register "GET /api/{name}" route (allowed for everyone)
		se.Router.POST("/api/v1/getparams.execute", func(e *core.RequestEvent) error {
			output := &PluginOutput{
				Output: PluginOutputParams{
					Parameters: []map[string]interface{}{},
				},
			}

			otelcolsCol, _ := app.FindCollectionByNameOrId("otelcols")
			otelcols, _ := app.FindAllRecords(otelcolsCol)
			for _, otelcol := range otelcols {
				output.Output.Parameters = append(output.Output.Parameters, map[string]interface{}{
					"otelcol": otelcol.Get("id"),
					"tenant":  otelcol.Get("tenant"),
				})
			}

			return e.JSON(http.StatusOK, output)

		})

		// register "POST /api/myapp/settings" route (allowed only for authenticated users)
		// se.Router.POST("/api/myapp/settings", func(e *core.RequestEvent) error {
		// 	// do something ...
		// 	return e.JSON(http.StatusOK, map[string]bool{"success": true})
		// }).Bind(apis.RequireAuth())

		return se.Next()
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
