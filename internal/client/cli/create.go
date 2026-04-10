package cli

import "github.com/spf13/cobra"

type CreateOptions struct {
}

func NewCreateCommand() *cobra.Command {
	// opts := CreateOptions{}

	cmd := &cobra.Command{
		Use: "create",
	}

	cmd.AddCommand(NewCreateClusterCommand())

	return cmd
}
