package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

func init() {
	m.Register(func(app core.App) error {
		settings := app.Settings()

		// for all available settings fields you could check
		// https://github.com/pocketbase/pocketbase/blob/develop/core/settings_model.go#L121-L130
		settings.Meta.AppName = "telesto"
		settings.Meta.AppURL = "https://telesto.com"
		settings.Logs.MaxDays = 7
		settings.Logs.LogAuthId = true
		settings.Logs.LogIP = true

		return app.Save(settings)

	}, nil)
}
