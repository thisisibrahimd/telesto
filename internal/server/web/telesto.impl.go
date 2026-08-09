package web

import (
	"log/slog"
	"net/http"

	"github.com/jinzhu/copier"
	"github.com/thisisibrahimd/telesto/internal/server/middlewares"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/utils"
	"github.com/thisisibrahimd/telesto/templates/pages/telestos"
)

// ListTelestos implements [WebServerInterface].
func (s *WebServer) GetTelestos(w http.ResponseWriter, r *http.Request) {
	userID := middlewares.GetUserID(r.Context())

	userTelestos, err := s.storage.Repos.Telesto.ByUser(userID).GetAll(r.Context())
	if err != nil {
		slog.Error("failed to retirve telestos", slog.Any("error", err))
	}

	// render
	telestosModels := utils.Map(userTelestos, convertTelesto)
	telestos.Index(telestos.TelestosViewModel{Telestos: telestosModels}).Render(r.Context(), w)
}

// GetTelesto implements [WebServerInterface].
func (s *WebServer) GetTelesto(w http.ResponseWriter, r *http.Request) {
	userID := middlewares.GetUserID(r.Context())
	telestoID := r.PathValue("id")
	if telestoID == "" {
		slog.Error("")
		return
	}

	userTelesto, err := s.storage.Repos.Telesto.ByUser(userID).Get(r.Context(), telestoID)
	if err != nil {
		slog.Error("no telesto", slog.Any("error", err))
		return
	}

	// render
	telestos.Show(*convertTelesto(userTelesto)).Render(r.Context(), w)
}

// NewTelesto implements [WebServerInterface].
func (s *WebServer) NewTelesto(w http.ResponseWriter, r *http.Request) {
	telestos.New().Render(r.Context(), w)
}

type NewTelestoForm struct {
	Name string `json:"name" schema:"name,required"`
}

// NewTelestoExec implements [WebServerInterface].
func (s *WebServer) NewTelestoSubmit(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())

	err := r.ParseForm()
	if err != nil {
		return
	}

	var newTelestoForm NewTelestoForm
	if err := s.decoder.Decode(&newTelestoForm, r.Form); err != nil {
		return
	}
	newTelesto := &model.Telesto{}
	copier.Copy(newTelesto, newTelestoForm)
	newTelesto.UserID = userId
	if err := s.storage.Repos.Telesto.New(r.Context(), newTelesto); err != nil {
		return
	}
	http.Redirect(w, r, "/telestos/"+newTelesto.ID, http.StatusSeeOther)
}

// EditTelesto implements [WebServerInterface].
func (s *WebServer) EditTelesto(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	telestoId := r.PathValue("id")
	if telestoId == "" {
		return
	}

	telesto, err := s.storage.Repos.Telesto.ByUser(userId).Get(r.Context(), telestoId)
	if err != nil {
		return
	}

	telestos.Edit(*convertTelesto(telesto)).Render(r.Context(), w)
}

type EditTelestoForm struct {
	Name string `json:"name" schema:"name,required"`
}

// EditTelestoExec implements [WebServerInterface].
func (s *WebServer) EditTelestoSubmit(w http.ResponseWriter, r *http.Request) {
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
	if err := s.decoder.Decode(&updatedTelestoForm, r.Form); err != nil {
		return
	}
	updatedTelesto := &model.Telesto{
		Name: updatedTelestoForm.Name,
	}

	if _, err := s.storage.Repos.Telesto.ByUser(userId).Edit(r.Context(), telestoId, updatedTelesto); err != nil {
		return
	}
	http.Redirect(w, r, "/telestos/"+telestoId, http.StatusSeeOther)
}

// DeleteTelesto implements [WebServerInterface].
func (s *WebServer) DeleteTelesto(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	telestoId := r.PathValue("id")
	if telestoId == "" {
		return
	}

	if _, err := s.storage.Repos.Telesto.ByUser(userId).Delete(r.Context(), telestoId); err != nil {
		return
	}

	http.Redirect(w, r, "/telestos", http.StatusSeeOther)
}

func convertTelesto(o *model.Telesto) *telestos.TelestoModel {
	m := &telestos.TelestoModel{}
	copier.Copy(m, o)
	return m
}
