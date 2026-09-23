package private

import (
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/thisisibrahimd/telesto/internal/server/services"
)

type ArgoHandler struct {
	svcs *services.Services
}

// ExecuteParams POST /api/v1/getparams.execute
func (h *ArgoHandler) POSTExecuteParams(w http.ResponseWriter, r *http.Request) {
	type TelestoParameters struct {
		ID              string `json:"id"`
		Name            string `json:"name"`
		TokensAvailable bool   `json:"tokensAvailable"`
	}

	// read input
	type PluginInputParams struct {
		Parameters map[string]any `json:"parameters"`
	}
	type PluginInput struct {
		ApplicationSetName string            `json:"applicationSetName"`
		Input              PluginInputParams `json:"input,omitzero"`
	}
	var input *PluginInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		// Format error response
		slog.Error("error reading input", slog.Any("error", err))
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}

	// svc
	telestos, err := h.svcs.Telesto.GetAll(r.Context())
	if err != nil {
		slog.Error("error retriving telestos")
		return
		// return nil, xerrors.New("error retrieveing all telestos")
	}

	telestoParams := []*TelestoParameters{}
	for _, telesto := range telestos {
		telestoParam := &TelestoParameters{
			ID:              telesto.ID,
			Name:            telesto.Name,
			TokensAvailable: len(telesto.Tokens) > 0,
		}
		telestoParams = append(telestoParams, telestoParam)
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
