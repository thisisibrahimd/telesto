package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		collection := core.NewBaseCollection("otelcols")

		// restrict the list and view rules for record owners
		// collection.ListRule = types.Pointer("id = @request.auth.id")
		// collection.ViewRule = types.Pointer("id = @request.auth.id")

		tenantCol, _ := app.FindCollectionByNameOrId("tenants")
		// add extra fields in addition to the default ones
		collection.Fields.Add(
			&core.TextField{
				Name:     "otelcol_id",
				Required: true,
				Min:      4,
				Max:      64,
			},
			&core.FileField{
				Name: "otelcol_config",
				// Required: true,
			},
			&core.RelationField{
				Name:         "tenant",
				CollectionId: tenantCol.Id,
				Required:     true,
				MaxSelect:    1,
			},
		)

		return app.Save(collection)
	}, func(app core.App) error {
		collection, _ := app.FindCollectionByNameOrId("otelcol")
		if collection == nil {
			return nil // probably already deleted
		}

		return app.Delete(collection)
	})
}
