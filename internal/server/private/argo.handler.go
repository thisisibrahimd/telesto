package private

import (
	"encoding/json"
	"net/http"

	"github.com/thisisibrahimd/telesto/internal/server/services"
)

type ArgoHandler struct {
	svcs *services.Services
}

// ExecuteParams POST /api/v1/getparams.execute
func (h *ArgoHandler) POSTExecuteParams(w http.ResponseWriter, r *http.Request) {
	// read input
	type PluginInputParams struct {
		Parameters map[string]any `json:"parameters"`
	}
	type PluginInput struct {
		ApplicationSetName string            `json:"applicationSetName"`
		Input              PluginInputParams `json:"input"`
	}
	var input PluginInput
	if err := json.NewDecoder(r.Body).Decode(input); err != nil {
		// Format error response
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}

	// svc
	telestoParams, err := h.svcs.Argo.ExecuteParams(r.Context())
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
	}

	// render
	type PluginOutputParams struct {
		Parameters []map[string]any `json:"parameters"`
	}
	type PluginOutput struct {
		Output PluginOutputParams `json:"output"`
	}
	output := &PluginOutput{
		Output: PluginOutputParams{
			Parameters: []map[string]any{},
		},
	}
	for _, telestoParam := range telestoParams {
		output.Output.Parameters = append(output.Output.Parameters, map[string]any{"telesto": telestoParam})
	}
	_ = json.NewEncoder(w).Encode(output)
}

func NewArgoHandler(svcs *services.Services) *ArgoHandler {
	return &ArgoHandler{svcs: svcs}
}
