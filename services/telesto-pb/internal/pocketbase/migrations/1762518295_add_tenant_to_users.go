package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		tenants, _ := app.FindCollectionByNameOrId("tenants")
		users.Fields.Add(
			&core.RelationField{
				Name:         "tenant",
				CollectionId: tenants.Id,
				MaxSelect:    1,
			},
		)
		return app.Save(users)
	}, func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		users.Fields.RemoveByName("tenant")

		return app.Save(users)
	})
}
