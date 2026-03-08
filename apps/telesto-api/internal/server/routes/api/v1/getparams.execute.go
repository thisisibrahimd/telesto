package v1

import (
	"context"
	"net/http"
	"strings"

	"github.com/danielgtaylor/huma/v2"
	"github.com/thisisibrahimd/telesto/apps/telesto-api/internal/db/query"
	"gorm.io/gorm"
)

type GetParamsExecuteRoutes struct {
	api   huma.API
	db    *gorm.DB
	query *query.Query
}

func (r *GetParamsExecuteRoutes) WithDB(db *gorm.DB) *GetParamsExecuteRoutes {
	r.db = db
	return r
}
func (r *GetParamsExecuteRoutes) WithQuery(query *query.Query) *GetParamsExecuteRoutes {
	r.query = query
	return r
}
func (r *GetParamsExecuteRoutes) WithAPI(api huma.API) *GetParamsExecuteRoutes {
	r.api = api
	return r
}

type PluginInputParams struct {
	// The parameters passed in the ApplicationSet spec.generators.plugin.parameters field
	Parameters map[string]interface{} `json:"parameters"`
}
type PluginInput struct {
	ApplicationSetName string            `json:"applicationSetName"`
	Input              PluginInputParams `json:"input"`
}
type GetParamsExecutePostRequest struct {
	Body PluginInput
}

type PluginOutputParams struct {
	// Must be a list of object maps. Each map becomes a set of parameters for a new Application.
	Parameters []map[string]interface{} `json:"parameters"`
}
type PluginOutput struct {
	Output PluginOutputParams `json:"output"`
}
type GetParamsExecutePostResponse struct {
	Body PluginOutput
}

func (r *GetParamsExecuteRoutes) SetupRoutes() {
	o := r.query.OtelCol

	huma.Register(r.api, huma.Operation{
		OperationID: "get-params",
		Method:      http.MethodPost,
		Path:        "/getparams.execute",
		Summary:     "Get params for argocd application set",
	}, func(ctx context.Context, input *GetParamsExecutePostRequest) (*GetParamsExecutePostResponse, error) {
		output := &GetParamsExecutePostResponse{
			Body: PluginOutput{
				Output: PluginOutputParams{
					Parameters: []map[string]interface{}{},
				},
			},
		}

		otelcols, _ := o.WithContext(ctx).Find()
		for _, otelcol := range otelcols {
			output.Body.Output.Parameters = append(output.Body.Output.Parameters, map[string]interface{}{
				"otelcol": strings.ToLower(otelcol.ID),
			})
		}

		return output, nil
	})

}

func NewGetParamExecuteRoutes() *GetParamsExecuteRoutes {
	return &GetParamsExecuteRoutes{}
}
