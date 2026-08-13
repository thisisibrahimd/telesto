package web

import (
	"log/slog"
	"net/http"

	"github.com/jinzhu/copier"
	"github.com/thisisibrahimd/telesto/internal/server/middlewares"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/storage/repository"
	"github.com/thisisibrahimd/telesto/internal/token"
	"github.com/thisisibrahimd/telesto/internal/utils"
	"github.com/thisisibrahimd/telesto/templates/pages/tokens"
)

// GetTokens implements [WebServerInterface].
func (s *WebServer) GetTokens(w http.ResponseWriter, r *http.Request) {
	userID := middlewares.GetUserID(r.Context())

	userTokens, err := s.storage.Repos.Token.ByUser(userID).GetAll(r.Context())
	if err != nil {
		slog.Error("failed to retrive tokens", slog.Any("error", err))
	}

	// render
	tokenModels := convertTokens(userTokens)
	tokens.Index(tokens.TokensViewModel{Tokens: tokenModels}).Render(r.Context(), w)
}

// GetToken implements [WebServerInterface].
func (s *WebServer) GetToken(w http.ResponseWriter, r *http.Request) {
	userID := middlewares.GetUserID(r.Context())
	tokenID := r.PathValue("id")
	if tokenID == "" {
		slog.Error("")
		return
	}

	userToken, err := s.storage.Repos.Token.ByUser(userID).Get(r.Context(), tokenID)
	if err != nil {
		slog.Error("no token", slog.Any("error", err))
		return
	}

	defer func() {
		_, err := s.storage.Repos.Token.(*repository.TokenRepo).MarkTokenSeen(r.Context(), tokenID)
		if err != nil {
			slog.Error("unable to set token to seen", slog.Any("error", err))
			return
		}
	}()

	// render
	tokenModel := convertToken(userToken)
	tokenModel.TelestoID = userToken.TelestoID
	tokens.Show(*tokenModel).Render(r.Context(), w)
}

// NewToken implements [WebServerInterface].
func (s *WebServer) NewToken(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	telestos, err := s.storage.Repos.Telesto.ByUser(userId).GetAll(r.Context())
	if err != nil {
		return
	}
	telestoOptions := convertTelestosToTelestoOptions(telestos)
	tokens.New(telestoOptions).Render(r.Context(), w)
}

type NewTokenForm struct {
	Name      string `json:"name" schema:"name,required"`
	TelestoID string `json:"telesto_id" schema:"telesto_id,required"`
}

// NewTokenSubmit implements [WebServerInterface].
func (s *WebServer) NewTokenSubmit(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())

	err := r.ParseForm()
	if err != nil {
		slog.Error("failed to parse form", slog.Any("error", err))
		return
	}

	var newTokenForm NewTokenForm
	if err := s.decoder.Decode(&newTokenForm, r.Form); err != nil {
		slog.Error("failed to decode form", slog.Any("error", err))
		return
	}

	selectedTelesto, err := s.storage.Repos.Telesto.ByUser(userId).Get(r.Context(), newTokenForm.TelestoID)
	if err != nil {
		slog.Error("failed to find selected form", slog.Any("error", err))
		return
	}

	t := token.NewToken()
	newToken := &model.Token{
		Name:      newTokenForm.Name,
		UserID:    userId,
		TelestoID: selectedTelesto.ID,
		Token:     t,
		Seen:      false,
	}
	slog.Info(selectedTelesto.ID)
	if err := s.storage.Repos.Token.New(r.Context(), newToken); err != nil {
		slog.Error("failed to create new token", slog.Any("error", err))
		return
	}
	http.Redirect(w, r, "/tokens/"+newToken.ID, http.StatusSeeOther)
}

// EditToken implements [WebServerInterface].
func (s *WebServer) EditToken(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	tokenID := r.PathValue("id")
	if tokenID == "" {
		return
	}

	userToken, err := s.storage.Repos.Token.ByUser(userId).Get(r.Context(), tokenID)
	if err != nil {
		return
	}

	tokens.Edit(*convertToken(userToken)).Render(r.Context(), w)
}

type EditTokenForm struct {
	Name string `json:"name" schema:"name,required"`
}

// EditTokenSubmit implements [WebServerInterface].
func (s *WebServer) EditTokenSubmit(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	tokenID := r.PathValue("id")
	if tokenID == "" {
		return
	}
	err := r.ParseForm()
	if err != nil {
		return
	}
	var updatedTokenForm EditTelestoForm
	if err := s.decoder.Decode(&updatedTokenForm, r.Form); err != nil {
		return
	}
	updatedToken := &model.Token{
		Name: updatedTokenForm.Name,
	}

	if _, err := s.storage.Repos.Token.ByUser(userId).Edit(r.Context(), tokenID, updatedToken); err != nil {
		return
	}
	http.Redirect(w, r, "/tokens/"+tokenID, http.StatusSeeOther)
}

// DeleteToken implements [WebServerInterface].
func (s *WebServer) DeleteToken(w http.ResponseWriter, r *http.Request) {
	userId := middlewares.GetUserID(r.Context())
	tokenID := r.PathValue("id")
	if tokenID == "" {
		return
	}

	if _, err := s.storage.Repos.Token.ByUser(userId).Delete(r.Context(), tokenID); err != nil {
		return
	}

	if r.Header.Get("HX-Request") == "true" {
		w.Header().Set("HX-Redirect", "/tokens")
		w.WriteHeader(http.StatusOK)
		return
	}
	http.Redirect(w, r, "/tokens", http.StatusSeeOther)
}

func convertTokens(ts []*model.Token) []*tokens.TokenModel {
	convertedTokens := []*tokens.TokenModel{}
	for _, t := range ts {
		convertedToken := convertToken(t)
		convertedTokens = append(convertedTokens, convertedToken)
	}
	return convertedTokens
}

func convertToken(o *model.Token) *tokens.TokenModel {
	tokenModel := &tokens.TokenModel{}
	copier.Copy(tokenModel, o)
	return tokenModel
}

func convertTelestosToTelestoOptions(telestos []*model.Telesto) []*tokens.TelestoOption {
	return utils.Map(telestos, convertTelestoToTelestoOption)
}

func convertTelestoToTelestoOption(o *model.Telesto) *tokens.TelestoOption {
	telestoOption := &tokens.TelestoOption{}
	copier.Copy(telestoOption, o)
	return telestoOption
}
