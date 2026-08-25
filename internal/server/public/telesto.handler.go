package public

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/gorilla/schema"
	"github.com/jinzhu/copier"
	"github.com/thisisibrahimd/telesto/internal/server/middlewares"
	"github.com/thisisibrahimd/telesto/internal/server/services"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/utils"
	"github.com/thisisibrahimd/telesto/templates/pages/telestos"
)

type TelestoHandler struct {
	svcs          *services.Services
	schemaDecoder *schema.Decoder
}

func newTelestoHandler(svcs *services.Services, sd *schema.Decoder) *TelestoHandler {
	return &TelestoHandler{svcs: svcs, schemaDecoder: sd}
}

// ListTelestos implements [WebServerInterface].
func (h *TelestoHandler) GetTelestos(w http.ResponseWriter, r *http.Request) {
	// read input
	userID := middlewares.GetUserID(r.Context())

	// do stuff
	userTelestos, err := h.svcs.Telesto.ByUser(userID).GetAll(r.Context())
	if err != nil {
		slog.Error("failed to retirve telestos", slog.Any("error", err))
	}

	// render
	telestosModels := utils.Map(userTelestos, convertTelesto)
	telestos.Index(telestos.TelestosViewModel{Telestos: telestosModels}).Render(r.Context(), w)
}

// GetTelesto implements [WebServerInterface].
func (h *TelestoHandler) GetTelesto(w http.ResponseWriter, r *http.Request) {
	// read input
	userID := middlewares.GetUserID(r.Context())
	telestoID := r.PathValue("id")
	if telestoID == "" {
		slog.Error("")
		return
	}

	// do stuff
	userTelesto, err := h.svcs.Telesto.ByUser(userID).Get(r.Context(), telestoID)
	if err != nil {
		slog.Error("no telesto", slog.Any("error", err))
		return
	}

	// render
	telestos.Show(*convertTelesto(userTelesto)).Render(r.Context(), w)
}

type GetTelestoTokensResponse struct {
	Tokens string `json:"tokens"`
}

// GetTelestoTokens implements [WebServerInterface].
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

// NewTelesto implements [WebServerInterface].
func (h *TelestoHandler) NewTelesto(w http.ResponseWriter, r *http.Request) {
	telestos.New().Render(r.Context(), w)
}

type NewTelestoForm struct {
	Name string `json:"name" schema:"name,required"`
}

// NewTelestoExec implements [WebServerInterface].
func (h *TelestoHandler) NewTelestoSubmit(w http.ResponseWriter, r *http.Request) {
	// read input
	userId := middlewares.GetUserID(r.Context())

	err := r.ParseForm()
	if err != nil {
		return
	}

	var newTelestoForm NewTelestoForm
	if err := h.schemaDecoder.Decode(&newTelestoForm, r.Form); err != nil {
		return
	}
	newTelesto := &model.Telesto{}
	copier.Copy(newTelesto, newTelestoForm)
	newTelesto.UserID = userId

	// do stuff
	if err := h.svcs.Telesto.Create(r.Context(), newTelesto); err != nil {
		return
	}

	// render
	http.Redirect(w, r, "/telestos/"+newTelesto.ID, http.StatusSeeOther)
}

// EditTelesto implements [WebServerInterface].
func (h *TelestoHandler) EditTelesto(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	telestoId := r.PathValue("id")
	if telestoId == "" {
		return
	}

	telesto, err := h.svcs.Telesto.ByUser(userId).Get(r.Context(), telestoId)
	if err != nil {
		return
	}

	telestos.Edit(*convertTelesto(telesto)).Render(r.Context(), w)
}

type EditTelestoForm struct {
	Name string `json:"name" schema:"name,required"`
}

// EditTelestoExec implements [WebServerInterface].
func (h *TelestoHandler) EditTelestoSubmit(w http.ResponseWriter, r *http.Request) {
	// read input
	userId := middlewares.GetUserID(r.Context())
	telestoId := r.PathValue("id")
	if telestoId == "" {
		return
	}
	err := r.ParseForm()
	if err != nil {
		return
	}
	var updatedTelestoForm EditTelestoForm
	if err := h.schemaDecoder.Decode(&updatedTelestoForm, r.Form); err != nil {
		return
	}
	updatedTelesto := &model.Telesto{
		Name: updatedTelestoForm.Name,
	}

	// do stuff
	if err := h.svcs.Telesto.ByUser(userId).Update(r.Context(), telestoId, updatedTelesto); err != nil {
		return
	}

	// render
	http.Redirect(w, r, "/telestos/"+telestoId, http.StatusSeeOther)
}

// DeleteTelesto implements [WebServerInterface].
func (h *TelestoHandler) DeleteTelesto(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	telestoId := r.PathValue("id")
	if telestoId == "" {
		return
	}

	if err := h.svcs.Telesto.ByUser(userId).Delete(r.Context(), telestoId); err != nil {
		return
	}

	if r.Header.Get("HX-Request") == "true" {
		w.Header().Set("HX-Redirect", "/telestos")
		w.WriteHeader(http.StatusOK)
		return
	}
	http.Redirect(w, r, "/telestos", http.StatusSeeOther)
}

func convertTelesto(o *model.Telesto) *telestos.TelestoModel {
	m := &telestos.TelestoModel{}
	copier.Copy(m, o)
	return m
}
