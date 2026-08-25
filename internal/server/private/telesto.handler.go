package private

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/gorilla/schema"
	"github.com/thisisibrahimd/telesto/internal/server/services"
)

type TelestoHandler struct {
	svcs          *services.Services
	schemaDecoder *schema.Decoder
}

func newTelestoHandler(svcs *services.Services) *TelestoHandler {
	return &TelestoHandler{svcs: svcs}
}

type GetTelestoTokensResponse struct {
	Tokens string `json:"tokens"`
}

func (h *TelestoHandler) GetTelestoTokens(w http.ResponseWriter, r *http.Request) {
	// read input
	telestoID := r.PathValue("id")
	if telestoID == "" {
		slog.Error("no ")
		return
	}

	// do stuff
	telesto, err := h.svcs.Telesto.Get(r.Context(), telestoID)
	if err != nil {
		slog.Error("no telesto", slog.Any("error", err))
		return
	}

	// render
	resp := &GetTelestoTokensResponse{
		Tokens: "",
	}
	for _, token := range telesto.Tokens {
		resp.Tokens += fmt.Sprintf("%s # %s\n", token.Token, token.ID)
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		slog.Error("failed to encode json response", slog.Any("error", err))
		return
	}
}
