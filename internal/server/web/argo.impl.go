package web

import (
	"encoding/json"
	"net/http"
	"strings"
)

// ExecuteParams implements [WebServerInterface].
func (s *WebServer) ExecuteParams(w http.ResponseWriter, r *http.Request) {
	type PluginOutputParams struct {
		Parameters []map[string]any `json:"parameters"`
	}
	type PluginOutput struct {
		Output PluginOutputParams `json:"output"`
	}

	telestos, err := s.storage.Repos.Telesto.GetAll(r.Context())
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	output := &PluginOutput{
		Output: PluginOutputParams{
			Parameters: []map[string]any{},
		},
	}

	for _, telesto := range telestos {
		tokenMap := map[string]string{}
		for _, token := range telesto.Tokens {
			tokenMap[token.ID] = token.Token
		}
		output.Output.Parameters = append(output.Output.Parameters, map[string]any{
			"telesto": map[string]any{
				"id":              strings.ToLower(telesto.ID),
				"name":            strings.ToLower(telesto.Name),
				"tokensAvailable": len(telesto.Tokens) > 0,
			},
		})
	}

	_ = json.NewEncoder(w).Encode(output)
}
