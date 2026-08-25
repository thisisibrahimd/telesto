package services

import (
	"context"

	"github.com/mdobak/go-xerrors"
	"github.com/thisisibrahimd/telesto/internal/storage/model"
	"github.com/thisisibrahimd/telesto/internal/storage/repository"
)

type TelestoParameters struct {
	ID              string `json:"id"`
	Name            string `json:"name"`
	TokensAvailable bool   `json:"tokensAvailable"`
}

type IArgoService interface {
	ExecuteParams(context.Context) ([]*TelestoParameters, error)
}

type ArgoService struct {
	telestoRepo repository.Repo[model.Telesto]
}

// ExecuteParams gather all params for all delpoyable telestos for argocd/telesto-deployer to deploy
func (s *ArgoService) ExecuteParams(ctx context.Context) ([]*TelestoParameters, error) {
	telestos, err := s.telestoRepo.GetAll(ctx)
	if err != nil {
		return nil, xerrors.New("error retrieveing all telestos")
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

	return telestoParams, nil
}

func newArgoService(telestoRepo repository.Repo[model.Telesto]) IArgoService {
	return &ArgoService{telestoRepo: telestoRepo}
}
