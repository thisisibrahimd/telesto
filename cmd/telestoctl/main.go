package main

import (
	"context"
	"fmt"
	"os"

	_ "github.com/golang-migrate/migrate/v4/database/rqlite"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/spf13/cobra"
	"github.com/thisisibrahimd/telesto/internal/client/cli"
)

var telestoctlCmd = &cobra.Command{
	Use: "telestoctl",
}

func main() {
	ctx := context.Background()

	// add default flags
	telestoctlCmd.PersistentFlags().String("username", "", "username for telesto")
	telestoctlCmd.PersistentFlags().String("endpoint", "http://localhost:9000", "endpoint")
	telestoctlCmd.PersistentFlags().String("token", os.Getenv("TELESTO_TOKEN"), "token")
	telestoctlCmd.AddCommand(cli.NewGetCommand())
	telestoctlCmd.AddCommand(cli.NewLoginCommand())

	// launch command
	if err := telestoctlCmd.ExecuteContext(ctx); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
