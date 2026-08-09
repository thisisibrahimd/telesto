package web

import (
	"encoding/json"
	"net/http"
	"strings"
)

// ExecuteParams implements [WebServerInterface].
func (s *WebServer) ExecuteParams(w http.ResponseWriter, r *http.Request) {
	type PluginInputParams struct {
		// The parameters passed in the ApplicationSet spec.generators.plugin.parameters field
		Parameters map[string]interface{} `json:"parameters"`
	}
	type PluginInput struct {
		ApplicationSetName string            `json:"applicationSetName"`
		Input              PluginInputParams `json:"input"`
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

	telestos, err := s.storage.Repos.Telesto.GetAll(r.Context())
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	output := &PluginOutput{
		Output: PluginOutputParams{
			Parameters: []map[string]interface{}{},
		},
	}

	for _, telesto := range telestos {
		output.Output.Parameters = append(output.Output.Parameters, map[string]interface{}{
			"telesto": map[string]any{
				"id":   strings.ToLower(telesto.ID),
				"name": strings.ToLower(telesto.Name),
			},
		})
	}

	_ = json.NewEncoder(w).Encode(output)
}
