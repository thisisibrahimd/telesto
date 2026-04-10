package cli

import (
	"context"
	"fmt"
	"net/http"
	"os"

	"github.com/jedib0t/go-pretty/v6/table"
	"github.com/mdobak/go-xerrors"
	"github.com/spf13/cobra"
	"github.com/thisisibrahimd/telesto/internal/client/lib/apiclient"
)

type GetClusterOptions struct {
}

func NewGetClustersCommand() *cobra.Command {
	// opts := GetClusterOptions{}

	cmd := &cobra.Command{
		Use:     "clusters",
		Aliases: []string{"cluster", "c"},
		Args:    cobra.MatchAll(cobra.MaximumNArgs(1)),
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx := cmd.Context()

			// l := telemetry.NewLogger()

			endpoint, err := cmd.Flags().GetString("endpoint")
			if err != nil {
				return xerrors.New("unable to read endpoint flag", err)
			}

			token, _ := cmd.Flags().GetString("token")
			apiClient, err := apiclient.NewClientWithResponses(endpoint)
			if err != nil {
				return xerrors.New("api client generation failed", err)
			}

			// single
			if len(args) != 0 && args[0] != "" {
				id := args[0]
				t := getTableWriter()
				t.AppendHeader(table.Row{"ID", "Name"})
				res, err := apiClient.GetOtelcolWithResponse(ctx, id)
				if err != nil {
					return xerrors.New("http request failed", err)
				}

				t.AppendRows([]table.Row{
					{*res.JSON200.Id, *res.JSON200.Name},
				})
				t.Render()

			} else {
				t := getTableWriter()
				t.AppendHeader(table.Row{"ID", "Name"})
				// multiple
				res, err := apiClient.ListOtelcolWithResponse(ctx, func(ctx context.Context, req *http.Request) error {
					req.Header.Add("Authorization", fmt.Sprintf("Bearer %s", token))
					return nil

				})
				if err != nil {
					return xerrors.New("http request failed", err)
				}

				if res.JSON200 == nil {
					println(res.Status())
					return xerrors.New("request failed")
				}

				for _, o := range *res.JSON200.Items {
					t.AppendRows([]table.Row{
						{*o.Id, *o.Name},
					})
				}
				t.Render()

			}

			return nil
		},
	}

	return cmd
}

func getTableWriter() table.Writer {
	t := table.NewWriter()
	t.Style().Options.DrawBorder = false
	t.Style().Options.SeparateColumns = false
	t.Style().Options.SeparateFooter = false
	t.Style().Options.SeparateHeader = false
	t.SetOutputMirror(os.Stdout)
	return t

}
