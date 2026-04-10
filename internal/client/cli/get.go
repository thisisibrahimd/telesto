package cli

import "github.com/spf13/cobra"

type GetOptions struct {
	ID string
}

func NewGetCommand() *cobra.Command {
	opts := GetOptions{}

	cmd := &cobra.Command{
		Use: "get",
	}

	cmd.PersistentFlags().StringVar(&opts.ID, "id", "", "id of resource")

	cmd.AddCommand(NewGetClustersCommand())

	return cmd
}
