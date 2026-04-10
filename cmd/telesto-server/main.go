package main

import (
	"context"
	"fmt"
	"os"

	_ "github.com/golang-migrate/migrate/v4/database/rqlite"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/spf13/cobra"
	"github.com/thisisibrahimd/telesto/internal/server/cli"
)

var telestoCmd = &cobra.Command{
	Use: "telesto",
}

func main() {
	ctx := context.Background()

	// register commands
	telestoCmd.AddCommand(cli.NewMigrateCommand())
	telestoCmd.AddCommand(cli.NewServeCommand())

	// launch command
	if err := telestoCmd.ExecuteContext(ctx); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
