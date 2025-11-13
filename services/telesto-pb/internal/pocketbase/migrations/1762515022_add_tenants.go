package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		// init a new auth collection with the default system fields and auth options
		collection := core.NewBaseCollection("tenants")

		// restrict the list and view rules for record owners
		// collection.ListRule = types.Pointer("id = @request.auth.id")
		// collection.ViewRule = types.Pointer("id = @request.auth.id")

		// add extra fields in addition to the default ones
		collection.Fields.Add(
			&core.TextField{
				Name:     "tenant_id",
				Required: true,
				Min:      4,
				Max:      64,
			},
			&core.TextField{
				Name:     "tenant_name",
				Required: true,
				Min:      4,
				Max:      64,
			},
		)

		return app.Save(collection)
	}, func(app core.App) error {
		collection, _ := app.FindCollectionByNameOrId("tenants")
		if collection == nil {
			return nil // probably already deleted
		}

		return app.Delete(collection)
	})
}
