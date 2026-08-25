package public

import (
	"log/slog"
	"net/http"

	"github.com/gorilla/schema"
	"github.com/jinzhu/copier"
	"github.com/mdobak/go-xerrors"
	"github.com/thisisibrahimd/telesto/internal/server/middlewares"
	"github.com/thisisibrahimd/telesto/internal/server/services"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/token"
	"github.com/thisisibrahimd/telesto/internal/utils"
	"github.com/thisisibrahimd/telesto/templates/pages/tokens"
)

type TokenHandler struct {
	svcs          *services.Services
	schemaDecoder *schema.Decoder
}

func newTokenHandler(svcs *services.Services, sd *schema.Decoder) *TokenHandler {
	return &TokenHandler{svcs: svcs, schemaDecoder: sd}
}

func (h *TokenHandler) GetTokens(w http.ResponseWriter, r *http.Request) {
	userID := middlewares.GetUserID(r.Context())

	userTokens, err := h.svcs.Token.ByUser(userID).GetAll(r.Context())
	if err != nil {
		slog.Error("failed to retrive tokens", slog.Any("error", err))
	}

	// render
	tokenModels := convertTokens(userTokens)
	tokens.Index(tokens.TokensViewModel{Tokens: tokenModels}).Render(r.Context(), w)
}

func (h *TokenHandler) GetToken(w http.ResponseWriter, r *http.Request) {
	userID := middlewares.GetUserID(r.Context())
	tokenID := r.PathValue("id")
	if tokenID == "" {
		slog.Error("")
		return
	}

	userToken, err := h.svcs.Token.ByUser(userID).Get(r.Context(), tokenID)
	if err != nil {
		slog.Error("no token", slog.Any("error", err))
		http.Error(w, xerrors.New("no token").Error(), http.StatusInternalServerError)
		return
	}

	// render
	tokenModel := convertToken(userToken)
	tokenModel.TelestoID = userToken.TelestoID
	tokens.Show(*tokenModel).Render(r.Context(), w)

	if err := h.svcs.Token.ByUser(userID).(services.ITokenService).MarkSeen(r.Context(), tokenID); err != nil {
		slog.Error("error marking token as seen", slog.Any("error", err))
	}
}

func (h *TokenHandler) NewToken(w http.ResponseWriter, r *http.Request) {
	userID := middlewares.GetUserID(r.Context())
	telestos, err := h.svcs.Telesto.ByUser(userID).GetAll(r.Context())
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

func (h *TokenHandler) NewTokenSubmit(w http.ResponseWriter, r *http.Request) {
	userID := middlewares.GetUserID(r.Context())

	err := r.ParseForm()
	if err != nil {
		slog.Error("failed to parse form", slog.Any("error", err))
		return
	}

	var newTokenForm NewTokenForm
	if err := h.schemaDecoder.Decode(&newTokenForm, r.Form); err != nil {
		slog.Error("failed to decode form", slog.Any("error", err))
		return
	}

	selectedTelesto, err := h.svcs.Telesto.ByUser(userID).Get(r.Context(), newTokenForm.TelestoID)
	if err != nil {
		slog.Error("failed to find selected form", slog.Any("error", err))
		return
	}

	t := token.NewToken()
	newToken := &model.Token{
		Name:      newTokenForm.Name,
		UserID:    userID,
		TelestoID: selectedTelesto.ID,
		Token:     t,
		Seen:      false,
	}
	if err := h.svcs.Token.ByUser(userID).Create(r.Context(), newToken); err != nil {
		slog.Error("failed to create new token", slog.Any("error", err))
		return
	}
	http.Redirect(w, r, "/tokens/"+newToken.ID, http.StatusSeeOther)
}

func (h *TokenHandler) EditToken(w http.ResponseWriter, r *http.Request) {
	userID := middlewares.GetUserID(r.Context())
	tokenID := r.PathValue("id")
	if tokenID == "" {
		return
	}

	userToken, err := h.svcs.Token.ByUser(userID).Get(r.Context(), tokenID)
	if err != nil {
		return
	}

	tokens.Edit(*convertToken(userToken)).Render(r.Context(), w)
}

type EditTokenForm struct {
	Name string `json:"name" schema:"name,required"`
}

func (h *TokenHandler) EditTokenSubmit(w http.ResponseWriter, r *http.Request) {
	userID := middlewares.GetUserID(r.Context())
	tokenID := r.PathValue("id")
	if tokenID == "" {
		return
	}
	err := r.ParseForm()
	if err != nil {
		return
	}
	var updatedTokenForm EditTelestoForm
	if err := h.schemaDecoder.Decode(&updatedTokenForm, r.Form); err != nil {
		return
	}
	updatedToken := &model.Token{
		Name: updatedTokenForm.Name,
	}

	if err := h.svcs.Token.ByUser(userID).Update(r.Context(), tokenID, updatedToken); err != nil {
		return
	}
	http.Redirect(w, r, "/tokens/"+tokenID, http.StatusSeeOther)
}

func (h *TokenHandler) DeleteToken(w http.ResponseWriter, r *http.Request) {
	userID := middlewares.GetUserID(r.Context())
	tokenID := r.PathValue("id")
	if tokenID == "" {
		return
	}

	if err := h.svcs.Token.ByUser(userID).Delete(r.Context(), tokenID); err != nil {
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
