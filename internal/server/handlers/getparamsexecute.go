package handlers

// import (
// 	"context"
// 	"net/http"
// 	"strings"

// 	"github.com/danielgtaylor/huma/v2"
// 	"github.com/thisisibrahimd/telesto/internal/storage"
// )

// type GetParamsExecuteHandler struct {
// 	Handler
// 	storage *storage.Storage
// }

// func (h *GetParamsExecuteHandler) SetStorage(sto *storage.Storage) {}

// func (h *GetParamsExecuteHandler) RegisterRoutes(api huma.API) {
// 	h.RegisterGetParams(api)
// }
// func (h *GetParamsExecuteHandler) RegisterGetParams(api huma.API) {
// 	type PluginInputParams struct {
// 		// The parameters passed in the ApplicationSet spec.generators.plugin.parameters field
// 		Parameters map[string]interface{} `json:"parameters"`
// 	}
// 	type PluginInput struct {
// 		ApplicationSetName string            `json:"applicationSetName"`
// 		Input              PluginInputParams `json:"input"`
// 	}
// 	type GetParamsExecutePostRequest struct {
// 		Body PluginInput
// 	}

// 	type PluginOutputParams struct {
// 		// Must be a list of object maps. Each map becomes a set of parameters for a new Application.
// 		Parameters []map[string]interface{} `json:"parameters"`
// 	}
// 	type PluginOutput struct {
// 		Output PluginOutputParams `json:"output"`
// 	}
// 	type GetParamsExecutePostResponse struct {
// 		Body PluginOutput
// 	}

// 	huma.Register(api, huma.Operation{
// 		OperationID: "get-params",
// 		Method:      http.MethodPost,
// 		Path:        "/getparams.execute",
// 		Summary:     "Get params for argocd application set",
// 	}, func(ctx context.Context, input *GetParamsExecutePostRequest) (*GetParamsExecutePostResponse, error) {
// 		output := &GetParamsExecutePostResponse{
// 			Body: PluginOutput{
// 				Output: PluginOutputParams{
// 					Parameters: []map[string]interface{}{},
// 				},
// 			},
// 		}

// 		otelcols, err := h.storage.Query.Otelcol.WithContext(ctx).Find()
// 		if err != nil {
// 			return nil, err
// 		}
// 		for _, otelcol := range otelcols {
// 			output.Body.Output.Parameters = append(output.Body.Output.Parameters, map[string]interface{}{
// 				"otelcol": map[string]string{
// 					"id":   strings.ToLower(otelcol.ID),
// 					"name": strings.ToLower(otelcol.Name),
// 				},
// 			})
// 		}

// 		return output, nil
// 	})
// }

// func NewGetParamsExecuteHandler(opts ...HandlerOption) Handler {
// 	getParamsExecuteHandler := &GetParamsExecuteHandler{}
// 	for _, opt := range opts {
// 		opt(getParamsExecuteHandler)
// 	}

// 	return getParamsExecuteHandler
// }
