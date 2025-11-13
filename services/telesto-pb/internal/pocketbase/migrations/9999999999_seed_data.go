package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		users, _ := app.FindCollectionByNameOrId("users")
		tenants, _ := app.FindCollectionByNameOrId("tenants")
		otelcols, _ := app.FindCollectionByNameOrId("otelcols")

		fakeTenants := []struct {
			id         string
			tenantId   string
			tenantName string
		}{
			{
				id:         "aaaaaaaaaaaaaaa",
				tenantId:   "apple",
				tenantName: "Apple",
			},
			{
				id:         "bbbbbbbbbbbbbbb",
				tenantId:   "banana",
				tenantName: "Banana",
			},
		}
		fakeEngineers := []struct {
			id       string
			email    string
			password string
			tenant   string
		}{
			{
				id:       "aaaaaaaaaaaaaaa",
				email:    "engineer@apple.com",
				password: "asdfasdf",
				tenant:   "aaaaaaaaaaaaaaa",
			},
			{
				id:       "bbbbbbbbbbbbbbb",
				email:    "engineer@banana.com",
				password: "asdfasdf",
				tenant:   "bbbbbbbbbbbbbbb",
			},
		}
		fakeOtelcol := []struct {
			id        string
			otelcolId string
			tenant    string
		}{
			{
				id:        "aaaaaaaaaaaaaaa",
				otelcolId: "apple",
				tenant:    "aaaaaaaaaaaaaaa",
			},
			{
				id:        "bbbbbbbbbbbbbbb",
				otelcolId: "banana",
				tenant:    "bbbbbbbbbbbbbbb",
			},
		}
		return app.RunInTransaction(func(txApp core.App) error {
			for _, tenant := range fakeTenants {
				tenantRecord := core.NewRecord(tenants)
				tenantRecord.Set("id", tenant.id)
				tenantRecord.Set("tenant_id", tenant.tenantId)
				tenantRecord.Set("tenant_name", tenant.tenantName)

				if err := txApp.Save(tenantRecord); err != nil {
					return err
				}
			}
			for _, engineer := range fakeEngineers {
				engineerRecord := core.NewRecord(users)
				engineerRecord.Set("id", engineer.id)
				engineerRecord.SetEmail(engineer.email)
				engineerRecord.SetPassword(engineer.password)
				engineerRecord.Set("tenant", engineer.tenant)

				if err := txApp.Save(engineerRecord); err != nil {
					return err
				}
			}
			for _, otelcol := range fakeOtelcol {
				otelcolRecord := core.NewRecord(otelcols)
				otelcolRecord.Set("id", otelcol.id)
				otelcolRecord.Set("otelcol_id", otelcol.otelcolId)
				otelcolRecord.Set("tenant", otelcol.tenant)

				if err := txApp.Save(otelcolRecord); err != nil {
					return err
				}
			}

			return nil
		})
	}, func(app core.App) error {
		// add down queries...

		return nil
	})
}
