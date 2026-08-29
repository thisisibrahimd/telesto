package private

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/gorilla/schema"
	"github.com/thisisibrahimd/telesto/internal/server/services"
	"github.com/thisisibrahimd/telesto/internal/telestoconfig"
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

type GetTelestoConfigResponse struct {
	Config string `json:"config"`
}

func (h *TelestoHandler) GetTelestoConfig(w http.ResponseWriter, r *http.Request) {
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

	// render otelcol config template
	telestoConfigTemplateData := telestoconfig.TemplateData{Telesto: telesto}
	telestoConfig, err := telestoconfig.Render(&telestoConfigTemplateData)
	if err != nil {
		slog.Error("error creating telesto config", slog.Any("error", err))
		http.Error(w, "failed", http.StatusInternalServerError)
		return
	}

	// render
	resp := &GetTelestoConfigResponse{
		Config: telestoConfig,
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		slog.Error("failed to encode json response", slog.Any("error", err))
		return
	}
}
