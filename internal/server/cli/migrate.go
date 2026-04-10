package cli

import (
	"github.com/spf13/cobra"
)

type MigrateOptions struct {
	DSN string
}

func NewMigrateCommand() *cobra.Command {
	opts := &MigrateOptions{}

	cmd := &cobra.Command{
		Use: "migrate",
		RunE: func(cmd *cobra.Command, args []string) error {
			// app := fx.New(
			// 	telemetryfx.Module,
			// 	fx.WithLogger(func(log *telemetry.Logger) fxevent.Logger {
			// 		return &fxevent.SlogLogger{Logger: log.Logger}
			// 	}),
			// 	// storage layer
			// 	fxutils.ProvideSuppliedGroupOption("storage-options", storage.WithDSN(opts.DSN)),
			// 	storagefx.Module,

			// 	fx.Invoke(func(lc fx.Lifecycle, sto *storage.Storage, l *telemetry.Logger) {
			// 		lc.Append(fx.Hook{
			// 			OnStart: func(ctx context.Context) error {
			// 				err := sto.Migrate()
			// 				if err != nil {
			// 					l.Logger.ErrorContext(ctx, "migrated failed", slog.Any("error", err))
			// 					return err
			// 				}

			// 				l.Logger.InfoContext(ctx, "migrated completed successfully")
			// 				return nil
			// 			},
			// 		})
			// 	}),
			// )

			// err := app.Start(cmd.Context())
			// if err != nil {
			// 	return err
			// }

			return nil
		},
	}

	cmd.Flags().StringVar(&opts.DSN, "dsn", "http://localhost:4001/?x-connect-insecure=true", "rqlite dsn string")

	return cmd
}
